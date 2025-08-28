import gleam/int
import gleam/option.{None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/regexp
import gleam/result
import gleam/string
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type SchemaError, InvalidComparison,
  InvalidProperty, Property, SchemaError, SchemaFailure, Valid,
}
import simplejson/jsonvalue.{type JsonValue, JsonString}

pub const string_properties = [
  Property("maxLength", types.Integer, types.gtezero_fn, Some(max_length)),
  Property("minLength", types.Integer, types.gtezero_fn, Some(min_length)),
  Property("pattern", types.String, validate_regex, Some(pattern)),
]

fn validate_regex(
  v: JsonValue,
  _c: Context,
  p: types.Property,
) -> Result(Bool, SchemaError) {
  case v {
    JsonString(value, _) -> {
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
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  case v {
    JsonString(value, _) -> {
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
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use max_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )
  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case jsonvalue {
      JsonString(str, _) -> {
        case int.compare(string.length(str), max_val) {
          Eq | Lt -> #(Valid, ann)
          Gt -> #(InvalidComparison(v, "maxLength", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}

fn min_length(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  SchemaError,
) {
  use min_val <- result.try(
    jsonvalue.get_int_from_number(v) |> result.replace_error(SchemaError),
  )
  Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
    case jsonvalue {
      JsonString(str, _) -> {
        case int.compare(string.length(str), min_val) {
          Eq | Gt -> #(Valid, ann)
          Lt -> #(InvalidComparison(v, "minLength", jsonvalue), ann)
        }
      }
      _ -> #(SchemaFailure, ann)
    }
  })
}
