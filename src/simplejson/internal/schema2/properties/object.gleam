import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import simplejson/internal/schema2/types.{
  type NodeAnnotation, type SchemaError, type ValidationInfo, type Value,
  AlwaysFail, BooleanValue, IncorrectType, InvalidComparison, MissingKey,
  NoAnnotation, ObjectAnnotation, Property, SchemaError, SchemaFailure, Valid,
  ValidatorProperties,
}
import simplejson/internal/schema2/validator2
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
  ValidatorProperties(
    "unevaluatedProperties",
    types.Object(types.AnyType),
    types.ok_fn,
    Some(unevaluated_properties),
  ),
  ValidatorProperties(
    "dependentSchemas",
    types.Types([types.Object(types.AnyType), types.Boolean]),
    types.ok_fn,
    Some(dependent_schemas),
  ),
]

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
      Ok(fn(json: JsonValue, ann: NodeAnnotation) {
        case json {
          jsonvalue.JsonObject(d, _) -> {
            let valid =
              list.fold_until(validators, Valid, fn(_, e) {
                let #(key, validator) = e

                case dict.has_key(d, key) {
                  True -> {
                    case
                      validator2.do_validate(
                        json,
                        validator,
                        ObjectAnnotation(dict.new()),
                      )
                    {
                      #(Valid, _) -> Continue(Valid)
                      #(err, _) -> Stop(err)
                    }
                  }
                  False -> Continue(Valid)
                }
              })
            #(valid, ann)
          }
          _ -> #(IncorrectType(types.Object(types.AnyType), json), ann)
        }
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

fn unevaluated_properties(
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
      let json = jsonvalue.JsonObject(d, None)
      case get_validator(json) {
        Error(_) -> Error(types.InvalidProperty("unevaluatedProperties", json))
        Ok(validator) -> {
          Ok(fn(json: JsonValue, ann: NodeAnnotation) {
            let assert ObjectAnnotation(matches) = ann
            case json {
              jsonvalue.JsonObject(d, _) -> {
                dict.filter(d, fn(k, _) { dict.has_key(matches, k) })
                |> dict.to_list
                |> list.fold_until(#(Valid, ann), fn(state, entry) {
                  let assert ObjectAnnotation(matches) = state.1
                  let #(k, v) = entry
                  case validator2.do_validate(v, validator, NoAnnotation) {
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
