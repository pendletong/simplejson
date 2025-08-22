import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/order.{Eq, Gt, Lt}
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type SchemaError, type Value,
  BooleanValue, InvalidComparison, NumberValue, Property, SchemaError,
  SchemaFailure, Valid,
}
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
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  get_min_contains(v, "minContains")
}

pub fn get_min_contains(
  v: Value,
  name: String,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case ann {
          types.ArrayAnnotation(_, _, Some(l), _) -> {
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
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case ann {
          types.ArrayAnnotation(_, _, Some(l), _) -> {
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
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
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
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
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
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
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
