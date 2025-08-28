import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, type ValidationNode, type Value,
  ArrayAnnotation, BooleanValue, InvalidComparison, NoAnnotation, NumberValue,
  Property, SchemaError, SchemaFailure, Valid,
}
import simplejson/internal/schema2/validator2
import simplejson/internal/utils
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject}

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
  v: Value,
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
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  get_min_contains(v, "minContains")
}

pub fn get_min_contains(
  v: Value,
  name: String,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case ann {
          ArrayAnnotation(_, _, Some(l), _) -> {
            case int.compare(list.length(l), len) {
              Eq | Gt -> #(Valid, ann)
              Lt -> #(InvalidComparison(v, name, jsonvalue), ann)
            }
          }
          _ -> #(Valid, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn max_contains(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case ann {
          ArrayAnnotation(_, _, Some(l), _) -> {
            case int.compare(list.length(l), len) {
              Eq | Lt -> #(Valid, ann)
              Gt -> #(InvalidComparison(v, "minContains", jsonvalue), ann)
            }
          }

          _ -> #(Valid, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn max_items(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Lt -> #(Valid, ann)
              Gt -> #(InvalidComparison(v, "maxItems", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn min_items(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Gt -> #(Valid, ann)
              Lt -> #(InvalidComparison(v, "minItems", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn unique_items(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    BooleanValue(_, True) -> {
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
    BooleanValue(_, False) -> {
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
  v: Value,
  get_validator: fn(JsonValue) -> Result(ValidationNode, SchemaError),
) -> Result(
  fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    BooleanValue(_, b) -> {
      case b {
        True -> fn(_, _, ann) {
          let assert ArrayAnnotation(_, _, _, _) = ann
          #(Valid, ArrayAnnotation(..ann, items_all: Some(True)))
        }
        False -> fn(json, _, ann) {
          let assert ArrayAnnotation(
            items_index:,
            items_all:,
            contains:,
            contains_all:,
          ) = ann
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
              let assert jsonvalue.JsonArray(d, _) = json |> echo as "before"
              contains |> echo as "contains"
              case
                dict.filter(d, fn(k, _) {
                  !{ k <= index || list.contains(contains, k) }
                })
                |> echo as "after"
                |> dict.is_empty
              {
                True -> #(Valid, ann)
                False -> #(types.AlwaysFail, ann)
              }
            }
          }
        }
      }
      |> Ok
    }
    types.ObjectValue(_, d) -> {
      let json = jsonvalue.JsonObject(d, None)

      case get_validator(json) {
        Error(_) -> Error(types.InvalidProperty("unevaluatedItems", json))
        Ok(validator) -> {
          Ok(fn(json: JsonValue, schema: Schema, ann: NodeAnnotation) {
            let assert ArrayAnnotation(
              items_index:,
              items_all:,
              contains:,
              contains_all:,
            ) = ann
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
                let assert jsonvalue.JsonArray(d, _) = json |> echo as "before"
                dict.filter(d, fn(k, _) {
                  !{
                    k <= index |> echo
                    || list.contains(contains |> echo |> echo, k)
                  }
                })
                |> echo as "after"
                |> dict.to_list
                |> list.fold_until(#(Valid, ann), fn(_, entry) {
                  let #(_i, node) = entry
                  case
                    validator2.do_validate(
                      node,
                      validator,
                      schema,
                      NoAnnotation,
                    )
                  {
                    #(Valid, _) ->
                      list.Continue(#(
                        Valid,
                        ArrayAnnotation(..ann, items_all: Some(True)),
                      ))
                    #(v, _) -> list.Stop(#(v, ann))
                  }
                })
              }
            }
          })
        }
      }
    }
    _ -> Error(SchemaError)
  }
}
