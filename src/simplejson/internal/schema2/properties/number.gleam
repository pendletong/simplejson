import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import simplejson/internal/schema2/types.{
  type Value, InvalidComparison, NumberValue, Property, SchemaError,
  SchemaFailure, Valid, ValidationError, ok_fn,
}
import simplejson/jsonvalue.{type JsonValue, JsonNumber}

pub const num_properties = [
  #(
    Property("minimum", types.Types([types.Integer, types.Number]), ok_fn),
    minimum,
  ),
  #(
    Property(
      "exclusiveMinimum",
      types.Types([types.Integer, types.Number]),
      ok_fn,
    ),
    exclusive_minimum,
  ),
  #(
    Property("maximum", types.Types([types.Integer, types.Number]), ok_fn),
    maximum,
  ),
  #(
    Property(
      "exclusiveMaximum",
      types.Types([types.Integer, types.Number]),
      ok_fn,
    ),
    exclusive_maximum,
  ),
  #(
    Property(
      "multipleOf",
      types.Types([types.Integer, types.Number]),
      types.gtzero_fn,
    ),
    multiple_of,
  ),
]

fn multiple_of(
  v: Value,
) -> Result(fn(JsonValue) -> types.ValidationInfo, types.SchemaError) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(jsonvalue: JsonValue) {
        result.try(
          case value, or_value, jsonvalue {
            Some(i), _, JsonNumber(Some(i2), _, _, _) -> {
              int.modulo(i2, i) |> result.map(int.to_float)
            }
            Some(i), _, JsonNumber(_, Some(f2), _, _) -> {
              float.modulo(f2, int.to_float(i))
            }
            _, Some(f), JsonNumber(Some(i2), _, _, _) -> {
              float.modulo(int.to_float(i2), f)
            }
            _, Some(f), JsonNumber(_, Some(f2), _, _) -> {
              float.modulo(f2, f)
            }
            _, _, _ -> Error(Nil)
          }
            |> result.replace_error(SchemaFailure),
          fn(f_val) {
            case f_val |> echo == 0.0 {
              True -> Ok(Valid)
              False -> Error(ValidationError("Not multiple of"))
            }
          },
        )
        |> result.unwrap_both
      })
    }
    _ -> Error(SchemaError)
  }
}

fn do_compare_numbers(value, or_value, jsonvalue) {
  case value, or_value, jsonvalue {
    Some(i), None, JsonNumber(Some(i2), _, _, _) -> Ok(int.compare(i, i2))
    Some(i), None, JsonNumber(_, Some(f2), _, _) ->
      Ok(float.compare(int.to_float(i), f2))
    None, Some(f), JsonNumber(_, Some(f2), _, _) -> Ok(float.compare(f, f2))
    None, Some(f2), JsonNumber(Some(i2), _, _, _) ->
      Ok(float.compare(f2, int.to_float(i2)))
    _, _, _ -> Error(SchemaFailure)
  }
}

fn minimum(
  v: Value,
) -> Result(fn(JsonValue) -> types.ValidationInfo, types.SchemaError) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Eq) | Ok(order.Lt) -> Valid
          Ok(_) -> InvalidComparison(v, "minimum", jsonvalue)
          Error(err) -> err
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn exclusive_minimum(
  v: Value,
) -> Result(fn(JsonValue) -> types.ValidationInfo, types.SchemaError) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Lt) -> Valid
          Ok(_) -> InvalidComparison(v, "minimum", jsonvalue)
          Error(err) -> err
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn maximum(
  v: Value,
) -> Result(fn(JsonValue) -> types.ValidationInfo, types.SchemaError) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Eq) | Ok(order.Gt) -> Valid
          Ok(_) -> InvalidComparison(v, "minimum", jsonvalue)
          Error(err) -> err
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn exclusive_maximum(
  v: Value,
) -> Result(fn(JsonValue) -> types.ValidationInfo, types.SchemaError) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(jsonvalue: JsonValue) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Gt) -> Valid
          Ok(_) -> InvalidComparison(v, "minimum", jsonvalue)
          Error(err) -> err
        }
      })
    }
    _ -> Error(SchemaError)
  }
}
