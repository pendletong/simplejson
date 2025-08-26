import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type SchemaError,
  type ValidationInfo, type Value, AlwaysFail, BooleanValue, IncorrectType,
  InvalidComparison, MissingKey, NoAnnotation, ObjectAnnotation, Property,
  SchemaError, SchemaFailure, Valid, ValidatorProperties,
}
import simplejson/internal/schema2/validator2
import simplejson/internal/stringify
import simplejson/internal/utils
import simplejson/jsonvalue.{type JsonValue, JsonObject, JsonString}

pub const object_properties = [
  Property(
    "minProperties",
    types.Integer,
    types.gtezero_fn,
    Some(min_properties),
  ),
  Property(
    "maxProperties",
    types.Integer,
    types.gtezero_fn,
    Some(max_properties),
  ),
  Property(
    "required",
    types.Array(types.String),
    utils.unique_strings_fn,
    Some(required_properties),
  ),
  ValidatorProperties(
    "propertyNames",
    types.Types([types.Object(types.AnyType), types.Boolean]),
    types.ok_fn,
    Some(property_names),
  ),
  Property(
    "dependentRequired",
    types.Object(types.Array(types.String)),
    check_unique_dependents,
    Some(dependent_required),
  ),
  ValidatorProperties(
    "dependentSchemas",
    types.Object(types.AnyType),
    types.ok_fn,
    Some(dependent_schemas),
  ),
]

fn check_unique_dependents(
  v: Value,
  _context: Context,
  prop: Property,
) -> Result(Bool, SchemaError) {
  let assert types.ObjectValue(_, d) = v
  dict.values(d)
  |> list.try_each(fn(l) {
    case l {
      jsonvalue.JsonArray(a, _) -> {
        case utils.is_unique(stringify.dict_to_ordered_list(a)) {
          True -> Ok(Nil)
          False -> Error(types.InvalidProperty(prop.name, l))
        }
      }
      _ -> Error(SchemaError)
    }
  })
  |> result.replace(True)
}

fn dependent_required(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    types.ObjectValue(_, dependents) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonObject(l, _) -> {
            case
              dict.fold(dependents, [], fn(infos, key, dependents) {
                case dict.has_key(l, key) {
                  True -> {
                    let assert jsonvalue.JsonArray(dependents, _) = dependents

                    dict.values(dependents)
                    |> list.fold(infos, fn(infos, dep) {
                      let assert JsonString(dep, _) = dep
                      case dict.has_key(l, dep) {
                        True -> infos
                        False -> [
                          types.MissingDependent(key, dep, jsonvalue),
                          ..infos
                        ]
                      }
                    })
                  }
                  False -> infos
                }
              })
            {
              [] -> #(Valid, ann)
              infos -> #(types.MultipleInfo(infos), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn min_properties(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    types.NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonObject(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Gt -> #(Valid, ann)
              Lt -> #(InvalidComparison(v, "minProperties", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn max_properties(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    types.NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonObject(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Lt -> #(Valid, ann)
              Gt -> #(InvalidComparison(v, "maxProperties", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn dependent_schemas(
  v: Value,
  get_validator: fn(JsonValue) -> Result(types.ValidationNode, SchemaError),
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    types.ObjectValue(_, d) -> {
      use validators <- result.try(
        dict.to_list(d)
        |> list.try_map(fn(e) {
          let #(key, value) = e
          use validator <- result.try(get_validator(value))

          Ok(#(key, validator))
        }),
      )
      Ok(fn(json: JsonValue, annotation: NodeAnnotation) {
        let #(v, anns) = case json {
          jsonvalue.JsonObject(d, _) -> {
            list.fold_until(validators, #(Valid, []), fn(state, e) {
              let #(key, validator) = e
              validator |> echo
              let #(_, annotations) = state

              case dict.has_key(d, key) {
                True -> {
                  case
                    validator2.do_validate(json, validator, NoAnnotation)
                    |> echo
                  {
                    #(Valid, ann) -> Continue(#(Valid, [ann, ..annotations]))
                    #(err, _) -> Stop(#(err, [annotation]))
                  }
                }
                False -> Continue(#(Valid, annotations))
              }
            })
          }
          _ -> #(IncorrectType(types.Object(types.AnyType), json), [annotation])
        }
        #(v, types.do_merge_annotations([annotation, ..anns]))
      })
    }
    _ -> Error(SchemaError)
  }
}

fn required_properties(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    types.ArrayValue(_, l) -> {
      let keys =
        list.map(l, fn(j) {
          let assert JsonString(s, _) = j
          s
        })

      Ok(fn(json: JsonValue, ann: NodeAnnotation) {
        case json {
          jsonvalue.JsonObject(d, _) -> {
            case list.find(keys, fn(k) { !dict.has_key(d, k) }) {
              Error(_) -> #(Valid, ann)
              Ok(k) -> #(MissingKey(k), ann)
            }
          }
          _ -> #(IncorrectType(types.Object(types.AnyType), json), ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

pub fn unevaluated_properties(
  v: Value,
  get_validator: fn(JsonValue) -> Result(types.ValidationNode, SchemaError),
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    BooleanValue(_, b) -> {
      case b {
        True -> fn(json, ann) {
          let assert jsonvalue.JsonObject(d, _) = json
          let assert ObjectAnnotation(matched) = ann
          #(
            Valid,
            ObjectAnnotation(dict.merge(
              matched,
              dict.keys(d) |> list.map(fn(k) { #(k, Nil) }) |> dict.from_list,
            )),
          )
        }
        False -> fn(json, ann) {
          ann |> echo as "uneval"
          let assert jsonvalue.JsonObject(d, _) = json
          let assert ObjectAnnotation(matches) = ann
          let d = dict.fold(matches, d, fn(d, k, _) { dict.delete(d, k) })
          case dict.is_empty(d) {
            True -> #(Valid, ann)
            False -> #(AlwaysFail, ann)
          }
        }
      }
      |> Ok
    }
    types.ObjectValue(_, d) -> {
      let json = jsonvalue.JsonObject(d, None)

      case get_validator(json) {
        Error(_) -> Error(types.InvalidProperty("unevaluatedProperties", json))
        Ok(validator) -> {
          Ok(fn(json: JsonValue, ann: NodeAnnotation) {
            let assert ObjectAnnotation(matches) = ann
            case json {
              jsonvalue.JsonObject(d, _) -> {
                dict.filter(d, fn(k, _) { !dict.has_key(matches, k) })
                |> dict.to_list
                |> list.fold_until(#(Valid, ann), fn(state, entry) {
                  let assert ObjectAnnotation(matches) = state.1
                  let #(k, v) = entry
                  case validator2.do_validate(v, validator, state.1) {
                    #(Valid, _) ->
                      Continue(#(
                        Valid,
                        ObjectAnnotation(dict.insert(matches, k, Nil)),
                      ))
                    #(err, _) -> Stop(#(err, ann))
                  }
                })
              }
              _ -> #(IncorrectType(types.Object(types.AnyType), json), ann)
            }
          })
        }
      }
    }
    _ -> Error(SchemaError)
  }
}

fn property_names(
  v: Value,
  get_validator: fn(JsonValue) -> Result(types.ValidationNode, SchemaError),
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    BooleanValue(_, b) -> {
      case b {
        True -> fn(_, ann) { #(Valid, ann) }
        False -> fn(json, ann) {
          let assert jsonvalue.JsonObject(d, _) = json
          case dict.is_empty(d) {
            True -> #(Valid, ann)
            False -> #(AlwaysFail, ann)
          }
        }
      }
      |> Ok
    }
    types.ObjectValue(_, d) -> {
      {
        let json = jsonvalue.JsonObject(d, None)
        case get_validator(json) {
          Error(_) -> Error(types.InvalidProperty("propertyNames", json))
          Ok(validator) -> {
            Ok(fn(json: JsonValue, ann: NodeAnnotation) {
              case json {
                jsonvalue.JsonObject(d, _) -> {
                  dict.keys(d)
                  |> list.find_map(fn(key) {
                    case
                      validator2.do_validate(
                        JsonString(key, None),
                        validator,
                        NoAnnotation,
                      )
                    {
                      #(Valid, _) -> Error(Nil)
                      _ -> Ok(#(types.InvalidKey(key), ann))
                    }
                  })
                  |> result.replace_error(#(Valid, ann))
                  |> result.unwrap_both
                }
                _ -> #(IncorrectType(types.Object(types.AnyType), json), ann)
              }
            })
          }
        }
      }
    }
    _ -> Error(SchemaError)
  }
}
