import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import simplejson/internal/schema/types.{
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, ArrayAnnotation, Context,
  InvalidComparison, NodeAnnotation, Property, SchemaError, SchemaFailure, Valid,
}
import simplejson/internal/schema/validator
import simplejson/internal/utils
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonBool, JsonObject}

pub const array_properties = [
  Property("maxItems", types.Integer, types.gtezero_fn, Some(max_items)),
  Property("minItems", types.Integer, types.gtezero_fn, Some(min_items)),
  Property("uniqueItems", types.Boolean, types.ok_fn, Some(unique_items)),
  Property(
    "minContains",
    types.Integer,
    gtezero_with_contains_fn,
    Some(min_contains),
  ),
  Property(
    "maxContains",
    types.Integer,
    gtezero_with_contains_fn,
    Some(max_contains),
  ),
]

fn gtezero_with_contains_fn(
  v: JsonValue,
  c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  case c.current_node {
    JsonObject(d, _) -> {
      case dict.has_key(d, "contains") {
        True -> types.gtezero_fn(v, c, p)
        False -> types.ok_fn(v, c, p)
      }
    }
    _ -> Error(types.MissingProperty("contains"))
  }
}

fn min_contains(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  get_min_contains(v, "minContains")
}

pub fn get_min_contains(
  v: JsonValue,
  name: String,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use min_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )
  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case ann.array_annotation {
      Some(ArrayAnnotation(_, _, Some(l), _)) -> {
        case int.compare(list.length(l), min_val) {
          Eq | Gt -> #(Valid, ann)
          Lt -> #(InvalidComparison(v, name, jsonvalue), ann)
        }
      }
      _ -> #(Valid, ann)
    }
  })
}

fn max_contains(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use max_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )

  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case ann.array_annotation {
      Some(ArrayAnnotation(_, _, Some(l), _)) -> {
        case int.compare(list.length(l), max_val) {
          Eq | Lt -> #(Valid, ann)
          Gt -> #(InvalidComparison(v, "minContains", jsonvalue), ann)
        }
      }

      _ -> #(Valid, ann)
    }
  })
}

fn max_items(
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
      JsonArray(l, _) -> {
        case int.compare(dict.size(l), max_val) {
          Eq | Lt -> #(Valid, ann)
          Gt -> #(InvalidComparison(v, "maxItems", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}

fn min_items(
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
      JsonArray(l, _) -> {
        case int.compare(dict.size(l), min_val) {
          Eq | Gt -> #(Valid, ann)
          Lt -> #(InvalidComparison(v, "minItems", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}

fn unique_items(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    JsonBool(True, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case utils.is_unique(dict.values(l)) {
              True -> #(Valid, ann)
              False -> #(InvalidComparison(v, "uniqueItems", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    JsonBool(False, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonArray(_, _) -> {
            #(Valid, ann)
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

pub fn unevaluated_items(
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
        True -> #(context, fn(_, _, ann) {
          let arann = types.get_array_annotation(ann)
          #(
            Valid,
            NodeAnnotation(
              ..ann,
              array_annotation: Some(
                ArrayAnnotation(..arann, items_all: Some(True)),
              ),
            ),
          )
        })
        False -> #(context, fn(json, _, ann) {
          let ArrayAnnotation(
            items_index:,
            items_all:,
            contains:,
            contains_all:,
          ) = types.get_array_annotation(ann)
          case contains_all, items_all {
            Some(True), _ | _, Some(True) -> #(Valid, ann)
            _, _ -> {
              let index = case items_index {
                Some(i) -> i
                _ -> -1
              }
              let contains = case contains {
                Some(c) -> c
                _ -> []
              }
              let assert jsonvalue.JsonArray(d, _) = json
              case
                dict.filter(d, fn(k, _) {
                  !{ k <= index || list.contains(contains, k) }
                })
                |> dict.is_empty
              {
                True -> #(Valid, ann)
                False -> #(types.AlwaysFail, ann)
              }
            }
          }
        })
      }
      |> Ok
    }
    JsonObject(_, _) -> {
      case get_validator(context) {
        Ok(Context(_, Some(validator), _, _, _, _, _) as context) -> {
          Ok(
            #(context, fn(json: JsonValue, schema: Schema, ann: NodeAnnotation) {
              let arann = types.get_array_annotation(ann)
              let ArrayAnnotation(
                items_index:,
                items_all:,
                contains:,
                contains_all:,
              ) = arann
              case contains_all, items_all {
                Some(True), _ | _, Some(True) -> #(Valid, ann)
                _, _ -> {
                  let index = case items_index {
                    Some(i) -> i
                    _ -> -1
                  }
                  let contains = case contains {
                    Some(c) -> c
                    _ -> []
                  }
                  let assert jsonvalue.JsonArray(d, _) = json
                  dict.filter(d, fn(k, _) {
                    !{ k <= index || list.contains(contains, k) }
                  })
                  |> dict.to_list
                  |> list.fold_until(#(Valid, ann), fn(_, entry) {
                    let #(_i, node) = entry
                    case
                      validator.do_validate(
                        node,
                        validator,
                        schema,
                        NodeAnnotation([], None, None),
                      )
                    {
                      #(Valid, _) ->
                        list.Continue(#(
                          Valid,
                          NodeAnnotation(
                            ..ann,
                            array_annotation: Some(
                              ArrayAnnotation(..arann, items_all: Some(True)),
                            ),
                          ),
                        ))
                      #(v, _) -> list.Stop(#(v, ann))
                    }
                  })
                }
              }
            }),
          )
        }
        _ ->
          Error(types.InvalidProperty("unevaluatedItems", context.current_node))
      }
    }
    _ -> Error(SchemaError)
  }
}
