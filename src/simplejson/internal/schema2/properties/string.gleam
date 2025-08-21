import gleam/int
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/regexp
import gleam/string
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type SchemaError, type Value,
  InvalidComparison, InvalidProperty, NumberValue, Property, SchemaError,
  SchemaFailure, StringValue, Valid,
}
import simplejson/jsonvalue.{type JsonValue, JsonString}

pub const string_properties = [
  Property("maxLength", types.Integer, types.gtezero_fn, Some(max_length)),
  Property("minLength", types.Integer, types.gtezero_fn, Some(min_length)),
  Property("pattern", types.String, validate_regex, Some(pattern)),
]

fn validate_regex(
  v: Value,
  _c: Context,
  p: types.Property,
) -> Result(Bool, SchemaError) {
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

fn pattern(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    StringValue(_, value) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonString(str, _) -> {
            let assert Ok(r) = regexp.from_string(value)
            case regexp.check(r, str) {
              False -> #(InvalidComparison(v, "pattern", jsonvalue), ann)
              True -> #(Valid, ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn max_length(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(value), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonString(str, _) -> {
            case int.compare(string.length(str), value) {
              Eq | Lt -> #(Valid, ann)
              Gt -> #(InvalidComparison(v, "maxLength", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn min_length(
  v: Value,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    NumberValue(_, Some(value), _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case jsonvalue {
          JsonString(str, _) -> {
            case int.compare(string.length(str), value) {
              Eq | Gt -> #(Valid, ann)
              Lt -> #(InvalidComparison(v, "minLength", jsonvalue), ann)
            }
          }
          _ -> #(SchemaFailure, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}
