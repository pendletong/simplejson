import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{Options}
import gleam/result
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, FloatProperty, IntProperty,
  InvalidSchema, NumberProperty, ObjectProperty, StringProperty,
}
import simplejson/jsonvalue.{type JsonValue, JsonNumber, JsonObject, JsonString}

pub fn get_int_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      Ok(Some(IntProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_positive_int_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _, _)) if val >= 0 -> {
      Ok(Some(IntProperty(property, val)))
    }
    Ok(JsonNumber(_, Some(_val), _, _)) -> {
      Error(InvalidSchema(20))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_more_than_zero_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) if val >. 0.0 -> {
      Ok(Some(NumberProperty(property, None, Some(val))))
    }
    Ok(JsonNumber(_, _, Some(_val), _)) -> Error(InvalidSchema(6))
    Ok(JsonNumber(_, Some(val), _, _)) if val > 0 -> {
      Ok(Some(NumberProperty(property, Some(val), None)))
    }
    Ok(JsonNumber(_, Some(_val), _, _)) -> Error(InvalidSchema(6))
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_object_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonObject(_, val)) -> {
      Ok(Some(ObjectProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_float_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) -> {
      Ok(Some(FloatProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_number_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) -> {
      Ok(Some(NumberProperty(property, None, Some(val))))
    }
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      Ok(Some(NumberProperty(property, Some(val), None)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_string_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonString(_, val)) -> {
      Ok(Some(StringProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(7))
    _ -> Ok(None)
  }
}

pub fn get_pattern_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  use pattern <- result.try(get_string_property(property, dict))

  case pattern |> echo {
    Some(StringProperty(_, regex_str)) -> {
      case
        regexp.compile(
          regex_str,
          Options(case_insensitive: False, multi_line: False),
        )
      {
        Error(_) -> Error(InvalidSchema(8))
        Ok(_) -> Ok(pattern)
      }
    }
    None -> Ok(None)
    Some(_) -> Error(InvalidSchema(9))
  }
}
