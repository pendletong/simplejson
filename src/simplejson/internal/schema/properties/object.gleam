import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/error.{
  type InvalidEntry, FailedProperty, InvalidDataType, InvalidSchema,
}
import simplejson/internal/schema/properties/properties

import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, IntValue,
}

import simplejson/jsonvalue.{type JsonValue, JsonObject}

pub const object_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(PropertyValue), InvalidEntry),
    fn(PropertyValue) ->
      Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
  ),
) = [
  #("minProperties", properties.get_positive_int_property, min_props),
  #("maxProperties", properties.get_positive_int_property, max_props),
  // #("uniqueItems", get_bool_property, unique_items),
]

fn min_props(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value |> echo as "minprops" {
    IntValue(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonObject(l, _) -> {
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

fn max_props(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntValue(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonObject(l, _) -> {
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
