import bigdecimal
import bigdecimal/rounding
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/order.{Eq}
import gleam/result
import simplejson/internal/schema2/types.{
  type NodeAnnotation, InvalidComparison, Property, SchemaError, SchemaFailure,
  Valid, ValidationError, ok_fn,
}
import simplejson/jsonvalue.{type JsonValue, JsonNumber}

pub const num_properties = [
  Property(
    "minimum",
    types.Types([types.Integer, types.Number]),
    ok_fn,
    Some(minimum),
  ),

  Property(
    "exclusiveMinimum",
    types.Types([types.Integer, types.Number]),
    ok_fn,
    Some(exclusive_minimum),
  ),

  Property(
    "maximum",
    types.Types([types.Integer, types.Number]),
    ok_fn,
    Some(maximum),
  ),

  Property(
    "exclusiveMaximum",
    types.Types([types.Integer, types.Number]),
    ok_fn,
    Some(exclusive_maximum),
  ),

  Property(
    "multipleOf",
    types.Types([types.Integer, types.Number]),
    types.gtzero_fn,
    Some(multiple_of),
  ),
]

fn multiple_of(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  types.SchemaError,
) {
  case v {
    JsonNumber(value, or_value, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        result.try(
          case value, or_value, jsonvalue {
            Some(i), _, JsonNumber(Some(i2), _, _) -> {
              let assert Ok(mod) = int.modulo(i2, i)
              Ok(mod == 0)
            }
            Some(i), _, JsonNumber(_, Some(f2), _) -> {
              let assert Ok(v2) = bigdecimal.from_string(float.to_string(f2))
              let assert Ok(v) = bigdecimal.from_string(int.to_string(i))
              is_mult(v2, v)
            }
            _, Some(f), JsonNumber(Some(i2), _, _) -> {
              let assert Ok(v2) = bigdecimal.from_string(int.to_string(i2))
              let assert Ok(v) = bigdecimal.from_string(float.to_string(f))
              is_mult(v2, v)
            }
            _, Some(f), JsonNumber(_, Some(f2), _) -> {
              let assert Ok(v2) = bigdecimal.from_string(float.to_string(f2))
              let assert Ok(v) = bigdecimal.from_string(float.to_string(f))
              is_mult(v2, v)
            }
            _, _, _ -> Error(Nil)
          }
            |> result.replace_error(#(SchemaFailure, ann)),
          fn(is_mult) {
            case is_mult {
              True -> Ok(#(Valid, ann))
              False -> {
                let #(v1, v2) = case value, or_value, jsonvalue {
                  Some(i), _, JsonNumber(Some(i2), _, _) -> {
                    #(int.to_string(i2), int.to_string(i))
                  }
                  Some(i), _, JsonNumber(_, Some(f2), _) -> {
                    #(float.to_string(f2), int.to_string(i))
                  }
                  _, Some(f), JsonNumber(Some(i2), _, _) -> {
                    #(int.to_string(i2), float.to_string(f))
                  }
                  _, Some(f), JsonNumber(_, Some(f2), _) -> {
                    #(float.to_string(f2), float.to_string(f))
                  }
                  _, _, _ -> #("X", "X")
                }
                Error(#(
                  ValidationError(v1 <> " is not multiple of " <> v2),
                  ann,
                ))
              }
            }
          },
        )
        |> result.unwrap_both
      })
    }
    _ -> Error(SchemaError)
  }
}

fn is_mult(
  dividend: bigdecimal.BigDecimal,
  by divisor: bigdecimal.BigDecimal,
) -> Result(Bool, Nil) {
  case bigdecimal.compare(divisor, bigdecimal.zero()) == Eq {
    True -> Error(Nil)
    False ->
      {
        bigdecimal.divide(dividend, divisor, rounding.Floor)
        |> bigdecimal.rescale(0, rounding.Floor)
        |> bigdecimal.multiply(divisor)
        |> bigdecimal.subtract(dividend, _)
        |> bigdecimal.compare(bigdecimal.zero())
        == Eq
      }
      |> Ok
  }
}

fn do_compare_numbers(value, or_value, jsonvalue) {
  case value, or_value, jsonvalue {
    Some(i), None, JsonNumber(Some(i2), _, _) -> Ok(int.compare(i, i2))
    Some(i), None, JsonNumber(_, Some(f2), _) ->
      Ok(float.compare(int.to_float(i), f2))
    None, Some(f), JsonNumber(_, Some(f2), _) -> Ok(float.compare(f, f2))
    None, Some(f2), JsonNumber(Some(i2), _, _) ->
      Ok(float.compare(f2, int.to_float(i2)))
    _, _, _ -> Error(SchemaFailure)
  }
}

fn minimum(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  types.SchemaError,
) {
  case v {
    JsonNumber(value, or_value, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(Eq) | Ok(order.Lt) -> #(Valid, ann)
          Ok(_) -> #(InvalidComparison(v, "minimum", jsonvalue), ann)
          Error(err) -> #(err, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn exclusive_minimum(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  types.SchemaError,
) {
  case v {
    JsonNumber(value, or_value, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Lt) -> #(Valid, ann)
          Ok(_) -> #(InvalidComparison(v, "exclusiveMinimum", jsonvalue), ann)
          Error(err) -> #(err, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn maximum(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  types.SchemaError,
) {
  case v {
    JsonNumber(value, or_value, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(Eq) | Ok(order.Gt) -> #(Valid, ann)
          Ok(_) -> #(InvalidComparison(v, "maximum", jsonvalue), ann)
          Error(err) -> #(err, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}

fn exclusive_maximum(
  v: JsonValue,
) -> Result(
  fn(JsonValue, NodeAnnotation) -> #(types.ValidationInfo, NodeAnnotation),
  types.SchemaError,
) {
  case v {
    JsonNumber(value, or_value, _) -> {
      Ok(fn(jsonvalue: JsonValue, ann: NodeAnnotation) {
        case do_compare_numbers(value, or_value, jsonvalue) {
          Ok(order.Gt) -> #(Valid, ann)
          Ok(_) -> #(InvalidComparison(v, "exclusiveMaximum", jsonvalue), ann)
          Error(err) -> #(err, ann)
        }
      })
    }
    _ -> Error(SchemaError)
  }
}
