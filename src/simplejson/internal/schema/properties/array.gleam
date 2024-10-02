import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/properties/properties.{
  get_bool_property, get_positive_int_property,
}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, BooleanProperty, FailedProperty,
  IntProperty, InvalidDataType, InvalidSchema,
}

import simplejson/jsonvalue.{type JsonValue, JsonArray}

pub const array_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(ValidationProperty), InvalidEntry),
    fn(ValidationProperty) ->
      Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
  ),
) = [
  #("minItems", get_positive_int_property, min_items),
  #("maxItems", get_positive_int_property, max_items),
  #("uniqueItems", get_bool_property, unique_items),
]

fn min_items(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonArray(_, l) -> {
            case dict.size(l) >= i {
              True -> None
              False -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidDataType(v))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn max_items(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonArray(_, l) -> {
            case dict.size(l) <= i {
              True -> None
              False -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidSchema(35))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn unique_items(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    BooleanProperty(_, True) -> {
      Ok(fn(v) {
        case v {
          JsonArray(_, l) -> {
            case list.length(list.unique(dict.values(l))) == dict.size(l) {
              True -> None
              False -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidSchema(36))
        }
      })
    }
    BooleanProperty(_, False) -> Ok(fn(_) { None })
    _ -> Error(InvalidSchema(14))
  }
}
