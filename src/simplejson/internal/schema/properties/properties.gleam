import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{Options}
import gleam/result
import simplejson/internal/schema/error.{type InvalidEntry, InvalidSchema}
import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, BooleanValue, FloatValue, IntValue, NumberValue,
  ObjectValue, StringValue,
}
import simplejson/jsonvalue.{
  type JsonValue, JsonBool, JsonNumber, JsonObject, JsonString,
}

pub type Property {
  StringProperty
  EnumProperty(enum: List(JsonValue))
  AnyProperty(props: List(Property))
  ListProperty(prop: Property)
}

pub fn get_bool_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonBool(_, val)) -> {
      Ok(Some(BooleanValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_int_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      Ok(Some(IntValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_positive_int_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _, _)) if val >= 0 -> {
      Ok(Some(IntValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_more_than_zero_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) if val >. 0.0 -> {
      Ok(Some(NumberValue(property, None, Some(val))))
    }
    Ok(JsonNumber(_, _, Some(_val), _)) -> Error(InvalidSchema(6))
    Ok(JsonNumber(_, Some(val), _, _)) if val > 0 -> {
      Ok(Some(NumberValue(property, Some(val), None)))
    }
    Ok(JsonNumber(_, Some(_val), _, _)) -> Error(InvalidSchema(6))
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_object_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonObject(_, val)) -> {
      Ok(Some(ObjectValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_float_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) -> {
      Ok(Some(FloatValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_number_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, _, Some(val), _)) -> {
      Ok(Some(NumberValue(property, None, Some(val))))
    }
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      Ok(Some(NumberValue(property, Some(val), None)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_string_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonString(_, val)) -> {
      Ok(Some(StringValue(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(7))
    _ -> Ok(None)
  }
}

pub fn get_pattern_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  use pattern <- result.try(get_string_property(property, dict))

  case pattern {
    Some(StringValue(_, regex_str)) -> {
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
