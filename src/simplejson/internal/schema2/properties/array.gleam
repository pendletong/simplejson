import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{Some}
import gleam/order.{Eq, Gt, Lt}
import simplejson/internal/schema2/types.{
  type SchemaError, type ValidationInfo, type Value, BooleanValue,
  InvalidComparison, NumberValue, Property, SchemaError, SchemaFailure, Valid,
}
import simplejson/jsonvalue.{type JsonValue, JsonArray}

pub const array_properties = [
  #(Property("maxItems", types.Integer, types.gtezero_fn), max_items),
  #(Property("minItems", types.Integer, types.gtezero_fn), min_items),
  #(Property("uniqueItems", types.Boolean, types.ok_fn), unique_items),
]

fn max_items(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Lt -> Valid
              Gt -> InvalidComparison(v, "maxItems", jsonvalue)
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn min_items(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, Some(len), _) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case int.compare(dict.size(l), len) {
              Eq | Gt -> Valid
              Lt -> InvalidComparison(v, "minItems", jsonvalue)
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn unique_items(
  v: Value,
) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    BooleanValue(_, True) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonArray(l, _) -> {
            case is_unique(dict.values(l)) {
              True -> Valid
              False -> InvalidComparison(v, "uniqueItems", jsonvalue)
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    BooleanValue(_, False) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonArray(_, _) -> {
            Valid
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn is_unique(values: List(JsonValue)) -> Bool {
  let #(unique, _) =
    list.fold_until(values, #(True, dict.new()), fn(d, v) {
      let #(_, d) = d
      case dict.has_key(d, v) {
        True -> Stop(#(False, d))
        False -> Continue(#(True, dict.insert(d, v, Nil)))
      }
    })
  unique
}
