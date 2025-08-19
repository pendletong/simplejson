import gleam/int
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/regexp
import gleam/string
import simplejson/internal/schema2/types.{
  type SchemaError, type ValidationInfo, type Value, InvalidComparison,
  InvalidProperty, NumberValue, Property, SchemaError, SchemaFailure,
  StringValue, Valid,
}
import simplejson/jsonvalue.{type JsonValue, JsonString}

pub const string_properties = [
  #(Property("maxLength", types.Integer, types.gtezero_fn), max_length),
  #(Property("minLength", types.Integer, types.gtezero_fn), min_length),
  #(Property("pattern", types.String, validate_regex), pattern),
]

fn validate_regex(v: Value, p: types.Property) -> Result(Bool, SchemaError) {
  case v {
    types.StringValue(name: _, value:) -> {
      case regexp.from_string(value) {
        Error(_) ->
          Error(InvalidProperty(p.name, jsonvalue.JsonString(value, None)))
        Ok(_) -> Ok(True)
      }
    }
    _ -> Error(SchemaError)
  }
}

fn pattern(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    StringValue(_, value) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonString(str, _) -> {
            let assert Ok(r) = regexp.from_string(value)
            case regexp.check(r, str) {
              False -> InvalidComparison(v, "pattern", jsonvalue)
              True -> Valid
            }
          }
          _ -> SchemaFailure
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn max_length(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, Some(value), _) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case jsonvalue {
          JsonString(str, _) -> {
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
          JsonString(str, _) -> {
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
