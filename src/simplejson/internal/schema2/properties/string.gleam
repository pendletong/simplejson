import gleam/int
import gleam/option.{Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/string
import simplejson/internal/schema2/types.{
  type SchemaError, type ValidationInfo, type Value, InvalidComparison,
  NumberValue, SchemaError, SchemaFailure, Valid,
}
import simplejson/jsonvalue.{type JsonValue}

pub const string_properties = [
  #(types.Property("maxLength", types.Integer, types.gtezero_fn), max_length),
  #(types.Property("minLength", types.Integer, types.gtezero_fn), min_length),
]

fn max_length(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, Some(value), _) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          jsonvalue.JsonString(str, _) -> {
            case int.compare(string.length(str), value) {
              Eq | Lt -> Valid
              Gt -> InvalidComparison(v, "maxLength", jsonvalue)
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn min_length(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, Some(value), _) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          jsonvalue.JsonString(str, _) -> {
            case int.compare(string.length(str), value) {
              Eq | Gt -> Valid
              Lt -> InvalidComparison(v, "minLength", jsonvalue)
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}
