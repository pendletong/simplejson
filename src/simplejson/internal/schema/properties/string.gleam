import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/string
import simplejson/internal/schema/error.{
  type InvalidEntry, FailedProperty, InvalidDataType, InvalidSchema,
}
import simplejson/internal/schema/properties/properties.{
  get_pattern_property, get_positive_int_property, get_string_property,
}
import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, IntValue, StringValue,
}
import simplejson/jsonvalue.{type JsonValue, JsonString}

pub const string_properties = [
  #("minLength", get_positive_int_property, string_min_length),
  #("maxLength", get_positive_int_property, string_max_length),
  #("pattern", get_pattern_property, string_pattern),
  #("format", get_string_property, string_format),
]

fn string_min_length(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntValue(_, int_value) -> {
      Ok(fn(v) {
        case perform_check(v, fn(str) { string.length(str) >= int_value }) {
          True -> None
          False -> Some(FailedProperty(value, v))
        }
      })
    }
    _ -> Error(InvalidSchema(10))
  }
}

fn string_max_length(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntValue(_, int_value) -> {
      Ok(fn(v) {
        case perform_check(v, fn(str) { string.length(str) <= int_value }) {
          True -> None
          False -> Some(FailedProperty(value, v))
        }
      })
    }
    _ -> Error(InvalidSchema(11))
  }
}

fn string_pattern(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    StringValue(_, str_value) -> {
      Ok(fn(v) {
        let assert Ok(re) = regex.from_string(str_value)
        case perform_check(v, fn(str) { regex.check(re, str) }) {
          True -> None
          False -> Some(FailedProperty(value, v))
        }
      })
    }
    _ -> Error(InvalidSchema(12))
  }
}

fn perform_check(v: JsonValue, check: fn(String) -> Bool) -> Bool {
  case v {
    JsonString(_, str) -> check(str)
    _ -> False
  }
}

fn string_format(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    StringValue(_, _) -> {
      Ok(fn(_v) { None })
    }
    _ -> Error(InvalidSchema(13))
  }
}

pub fn validate_string(node: JsonValue) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonString(_, _) -> Ok(True)
    _ -> Error([InvalidDataType(node)])
  }
}
