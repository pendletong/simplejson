import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string
import simplejson/internal/schema/properties/properties.{
  get_pattern_property, get_positive_int_property, get_string_property,
}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, FailedProperty, IntProperty,
  InvalidSchema, StringProperty,
}
import simplejson/jsonvalue.{type JsonValue, JsonString}

pub const string_properties = [
  #("minLength", get_positive_int_property, string_min_length),
  #("maxLength", get_positive_int_property, string_max_length),
  #("pattern", get_pattern_property, string_pattern),
  #("format", get_string_property, string_format),
]

fn string_min_length(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, int_value) -> {
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
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntProperty(_, int_value) -> {
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
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    StringProperty(_, str_value) -> {
      Ok(fn(v) {
        let assert Ok(re) = regexp.from_string(str_value)
        case perform_check(v, fn(str) { regexp.check(re, str) }) {
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
    JsonString(str) -> check(str)
    _ -> False
  }
}

fn string_format(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    StringProperty(_, _) -> {
      Ok(fn(_v) { None })
    }
    _ -> Error(InvalidSchema(13))
  }
}
