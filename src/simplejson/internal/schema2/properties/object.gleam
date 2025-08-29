import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, type ValidationNode, AlwaysFail,
  Context, IncorrectType, InvalidComparison, MissingKey, NoAnnotation,
  ObjectAnnotation, Property, SchemaError, SchemaFailure, Valid,
  ValidatorProperties,
}
import simplejson/internal/schema2/validator2
import simplejson/internal/stringify
import simplejson/internal/utils
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonObject, JsonString,
}

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
  v: JsonValue,
  _context: Context,
  prop: Property,
) -> Result(Bool, SchemaError) {
  let assert JsonObject(d, _) = v
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
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    JsonObject(dependents, _) -> {
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
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use min_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )

  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case jsonvalue {
      JsonObject(l, _) -> {
        case int.compare(dict.size(l), min_val) {
          Eq | Gt -> #(Valid, ann)
          Lt -> #(InvalidComparison(v, "minProperties", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}

fn max_properties(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use max_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )
  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case jsonvalue {
      JsonObject(l, _) -> {
        case int.compare(dict.size(l), max_val) {
          Eq | Lt -> #(Valid, ann)
          Gt -> #(InvalidComparison(v, "maxProperties", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}

fn dependent_schemas(
  context: Context,
  get_validator: fn(Context) -> Result(Context, SchemaError),
) -> Result(
  #(
    Context,
    fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  ),
  SchemaError,
) {
  case context.current_node {
    JsonObject(d, _) as json -> {
      use #(context, validators) <- result.try(
        dict.to_list(d)
        |> list.try_fold(#(context, []), fn(acc, e) {
          let #(context, l) = acc
          let #(key, value) = e
          use context <- result.try(
            get_validator(Context(..context, current_node: value))
            |> utils.revert_current_node(json),
          )
          case context {
            Context(_, Some(validator), _, _) ->
              Ok(#(context, [#(key, validator), ..l]))
            _ -> Ok(#(context, l))
          }
        }),
      )

      Ok(
        #(
          Context(..context, current_node: json),
          fn(json: JsonValue, schema: Schema, annotation: NodeAnnotation) {
            let #(v, anns) = case json {
              jsonvalue.JsonObject(d, _) -> {
                list.fold_until(validators, #(Valid, []), fn(state, e) {
                  let #(key, validator) = e
                  let #(_, annotations) = state
                  case dict.has_key(d, key) {
                    True -> {
                      case
                        validator2.do_validate(
                          json,
                          validator,
                          schema,
                          NoAnnotation,
                        )
                      {
                        #(Valid, ann) ->
                          Continue(#(Valid, [ann, ..annotations]))
                        #(err, _) -> Stop(#(err, [annotation]))
                      }
                    }
                    False -> Continue(#(Valid, annotations))
                  }
                })
              }
              _ -> #(IncorrectType(types.Object(types.AnyType), json), [
                annotation,
              ])
            }
            #(v, types.do_merge_annotations([annotation, ..anns]))
          },
        ),
      )
    }
    _ -> Error(SchemaError)
  }
}

fn required_properties(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    JsonArray(l, _) -> {
      let keys =
        list.map(dict.values(l), fn(j) {
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
  context: Context,
  get_validator: fn(Context) -> Result(Context, SchemaError),
) -> Result(
  #(
    Context,
    fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  ),
  SchemaError,
) {
  case context.current_node {
    JsonBool(b, _) -> {
      case b {
        True -> #(context, fn(json, _, ann) {
          let assert jsonvalue.JsonObject(d, _) = json
          let assert ObjectAnnotation(matched) = ann
          #(
            Valid,
            ObjectAnnotation(dict.merge(
              matched,
              dict.keys(d) |> list.map(fn(k) { #(k, Nil) }) |> dict.from_list,
            )),
          )
        })
        False -> #(context, fn(json, _, ann) {
          let assert jsonvalue.JsonObject(d, _) = json
          let assert ObjectAnnotation(matches) = ann
          let d = dict.fold(matches, d, fn(d, k, _) { dict.delete(d, k) })
          case dict.is_empty(d) {
            True -> #(Valid, ann)
            False -> #(AlwaysFail, ann)
          }
        })
      }
      |> Ok
    }
    JsonObject(_, _) -> {
      case get_validator(context) {
        Ok(Context(_, Some(validator), _, _) as context) -> {
          Ok(
            #(context, fn(json: JsonValue, schema: Schema, ann: NodeAnnotation) {
              let assert ObjectAnnotation(matches) = ann |> echo as "UNEVAL"

              case json {
                jsonvalue.JsonObject(d, _) -> {
                  dict.filter(d, fn(k, _) { !dict.has_key(matches, k) })
                  |> dict.to_list
                  |> list.fold_until(#(Valid, ann), fn(state, entry) {
                    let assert ObjectAnnotation(matches) = state.1
                    let #(k, v) = entry
                    case validator2.do_validate(v, validator, schema, state.1) {
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
            }),
          )
        }
        _ ->
          Error(types.InvalidProperty(
            "unevaluatedProperties",
            context.current_node,
          ))
      }
    }
    _ -> Error(SchemaError)
  }
}

fn property_names(
  context: Context,
  get_validator: fn(Context) -> Result(Context, SchemaError),
) -> Result(
  #(
    Context,
    fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  ),
  SchemaError,
) {
  case context.current_node {
    JsonBool(b, _) -> {
      case b {
        True -> #(context, fn(_, _, ann) { #(Valid, ann) })
        False -> #(context, fn(json, _, ann) {
          let assert jsonvalue.JsonObject(d, _) = json
          case dict.is_empty(d) {
            True -> #(Valid, ann)
            False -> #(AlwaysFail, ann)
          }
        })
      }
      |> Ok
    }
    JsonObject(_, _) -> {
      {
        case get_validator(context) {
          Ok(Context(_, Some(validator), _, _) as context) -> {
            Ok(
              #(
                context,
                fn(json: JsonValue, schema: Schema, ann: NodeAnnotation) {
                  case json {
                    jsonvalue.JsonObject(d, _) -> {
                      dict.keys(d)
                      |> list.find_map(fn(key) {
                        case
                          validator2.do_validate(
                            JsonString(key, None),
                            validator,
                            schema,
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
                    _ -> #(
                      IncorrectType(types.Object(types.AnyType), json),
                      ann,
                    )
                  }
                },
              ),
            )
          }
          _ ->
            Error(types.InvalidProperty("propertyNames", context.current_node))
        }
      }
    }
    _ -> Error(SchemaError)
  }
}
