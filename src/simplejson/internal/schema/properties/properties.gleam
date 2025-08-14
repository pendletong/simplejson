import gleam/dict.{type Dict}
import gleam/float
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{Options}
import gleam/result
import simplejson/internal/schema/error.{
  type InvalidEntry, InvalidSchema, MissingProperty, NotMatchEnum,
}
import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, BooleanValue, FloatValue, IntValue, ListValue, NullValue,
  NumberValue, ObjectValue, StringValue,
}
import simplejson/internal/stringify
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub type Property {
  StringProperty
  EnumProperty(enum: List(JsonValue))
  AnyProperty(props: List(Property))
  ListProperty(prop: Property)
  NeededProperty(prop: Property)
}

pub fn get_property(
  property_name: String,
  property: Property,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case property {
    NeededProperty(prop) -> {
      case get_property(property_name, prop, dict) {
        Ok(None) -> Error(MissingProperty(property_name))
        _ as v -> v
      }
    }
    AnyProperty(props) -> {
      list.fold_until(props, Ok(None), fn(_, prop) {
        case get_property(property_name, prop, dict) {
          Ok(None) -> Stop(Ok(None))
          Ok(Some(val)) -> Stop(Ok(Some(val)))
          Error(err) -> Continue(Error(err))
        }
      })
    }
    EnumProperty(_) -> {
      case dict.get(dict, property_name) {
        Ok(value) -> {
          evaluate_property(property_name, property, value) |> result.map(Some)
        }
        Error(_) -> Ok(None)
      }
    }
    StringProperty -> {
      case dict.get(dict, property_name) {
        Ok(v) -> {
          evaluate_property(property_name, property, v) |> result.map(Some)
        }
        Error(_) -> Ok(None)
      }
    }
    ListProperty(list_prop) -> {
      case dict.get(dict, property_name) {
        Ok(JsonArray(list, _)) -> {
          use res <- result.try(
            list.try_map(stringify.dict_to_ordered_list(list), fn(entry) {
              evaluate_property(property_name, list_prop, entry)
            }),
          )

          Ok(Some(ListValue(property_name, res)))
        }
        Ok(_) -> Error(InvalidSchema(51))
        Error(_) -> Ok(None)
      }
    }
  }
  // case dict.get(dict, property_name) {
  //   Ok(value) -> {
  //     case Property {
  //       StringProperty -> {

  //       }
  //     }
  //   }
  //   Error(_) -> Ok(None)
  // }
}

fn evaluate_property(
  property_name: String,
  property: Property,
  value: JsonValue,
) -> Result(PropertyValue, InvalidEntry) {
  case property {
    AnyProperty(_) -> todo
    EnumProperty(enum) -> {
      case list.contains(enum, value) {
        True -> {
          Ok(value_to_property(property_name, value))
        }
        False -> Error(NotMatchEnum(value))
      }
    }
    ListProperty(_) -> todo
    NeededProperty(_) -> todo
    StringProperty -> {
      case value {
        JsonString(str_value, _) -> Ok(StringValue(property_name, str_value))
        _ -> Error(InvalidSchema(50))
      }
    }
  }
}

fn value_to_property(property_name, value) {
  case value {
    JsonBool(b, _) -> BooleanValue(property_name, b)
    JsonNumber(i, f, _, _) -> {
      case i, f {
        Some(i), None -> IntValue(property_name, i)
        None, Some(f) -> FloatValue(property_name, f)
        _, _ -> NumberValue(property_name, i, f)
      }
    }
    JsonObject(o, _) -> ObjectValue(property_name, o)
    JsonString(s, _) -> StringValue(property_name, s)
    JsonArray(l, _) ->
      ListValue(
        property_name,
        list.map(stringify.dict_to_ordered_list(l), fn(v) {
          value_to_property(property_name, v)
        }),
      )
    JsonNull(_) -> NullValue(property_name)
  }
}

pub fn get_bool_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonBool(val, _)) -> {
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
    Ok(JsonNumber(Some(val), _, _, _)) -> {
      Ok(Some(IntValue(property, val)))
    }
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      case float.floor(val) {
        fval if fval == val -> {
          Ok(Some(IntValue(property, float.truncate(fval))))
        }
        _ -> Error(InvalidSchema(6))
      }
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
    Ok(JsonNumber(Some(val), _, _, _)) if val >= 0 -> {
      Ok(Some(IntValue(property, val)))
    }
    Ok(JsonNumber(_, Some(val), _, _)) if val >=. 0.0 -> {
      case float.floor(val) {
        fval if fval == val -> {
          Ok(Some(IntValue(property, float.truncate(fval))))
        }
        _ -> Error(InvalidSchema(6))
      }
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
    Ok(JsonNumber(_, Some(val), _, _)) if val >. 0.0 -> {
      Ok(Some(NumberValue(property, None, Some(val))))
    }
    Ok(JsonNumber(_, Some(_val), _, _)) -> Error(InvalidSchema(6))
    Ok(JsonNumber(Some(val), _, _, _)) if val > 0 -> {
      Ok(Some(NumberValue(property, Some(val), None)))
    }
    Ok(JsonNumber(Some(_val), _, _, _)) -> Error(InvalidSchema(6))
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

pub fn get_object_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(PropertyValue), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonObject(val, _)) -> {
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
    Ok(JsonNumber(_, Some(val), _, _)) -> {
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
    Ok(JsonNumber(_, Some(val), _, _)) -> {
      Ok(Some(NumberValue(property, None, Some(val))))
    }
    Ok(JsonNumber(Some(val), _, _, _)) -> {
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
    Ok(JsonString(val, _)) -> {
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
