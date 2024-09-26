import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/string
import simplejson/internal/schema/properties/properties.{
  get_int_property, get_pattern_property, get_string_property,
}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, FailedProperty, IntProperty,
  InvalidSchema, StringProperty,
}
import simplejson/jsonvalue.{type JsonValue}

pub const string_properties = [
  #("minLength", get_int_property, string_min_length),
  #("maxLength", get_int_property, string_max_length),
  #("pattern", get_pattern_property, string_pattern),
  #("format", get_string_property, string_format),
]

fn string_min_length(
  value: ValidationProperty,
) -> Result(fn(String) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, int_value) -> {
      Ok(fn(v) {
        case string.length(v) >= int_value {
          True -> None
          False -> Some(FailedProperty(value, _))
        }
      })
    }
    _ -> Error(InvalidSchema(10))
  }
}

fn string_max_length(
  value: ValidationProperty,
) -> Result(fn(String) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, int_value) -> {
      Ok(fn(v) {
        case string.length(v) <= int_value {
          True -> None
          False -> Some(FailedProperty(value, _))
        }
      })
    }
    _ -> Error(InvalidSchema(11))
  }
}

fn string_pattern(
  value: ValidationProperty,
) -> Result(fn(String) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    StringProperty(_, str_value) -> {
      Ok(fn(v) {
        let assert Ok(re) = regex.from_string(str_value)
        case regex.check(re, v) {
          True -> None
          False -> Some(FailedProperty(value, _))
        }
      })
    }
    _ -> Error(InvalidSchema(12))
  }
}

fn string_format(
  value: ValidationProperty,
) -> Result(fn(String) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    StringProperty(_, _) -> {
      Ok(fn(_) { None })
    }
    _ -> Error(InvalidSchema(13))
  }
}
