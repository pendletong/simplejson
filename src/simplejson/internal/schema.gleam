import gleam/dict.{type Dict}
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regex.{Options}
import gleam/result
import gleam/string
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, JsonArray, JsonBool, JsonNumber, JsonObject,
  JsonString,
}

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
    validation: ValidationNode,
    sub_schema: Dict(String, Schema),
  )
}

pub opaque type ValidationProperty {
  StringProperty(name: String, value: String)
  IntProperty(name: String, value: Int)
  FloatProperty(name: String, value: Float)
  NumberProperty(name: String, value: Option(Int), or_value: Option(Float))
}

pub opaque type ValidationNode {
  SimpleValidation(valid: Bool)
  MultiNode(validations: List(ValidationNode))
  StringNode(
    properties: List(fn(String) -> Option(fn(JsonValue) -> InvalidEntry)),
  )
}

pub type InvalidEntry {
  InvalidEntry(node: JsonValue)
  FalseSchema
  InvalidSchema(p: Int)
  InvalidJson(ParseError)
  InvalidDataType(node: JsonValue)
  FailedProperty(prop: ValidationProperty, value: JsonValue)
}

pub fn validate(json: String, schema: String) -> #(Bool, List(InvalidEntry)) {
  case generate_schema(schema) {
    Error(_) -> #(False, [InvalidSchema(1)])
    Ok(schema) -> do_validate(json, schema)
  }
}

fn generate_schema(schema: String) -> Result(Schema, InvalidEntry) {
  use schema <- result.try(
    parser.parse(schema) |> result.replace_error(InvalidSchema(2)),
  )

  case generate_validation(schema, dict.new()) {
    Ok(#(validator, sub_schema)) ->
      Ok(Schema(None, None, schema, validator, sub_schema))
    Error(err) -> Error(err)
  }
  |> io.debug
}

fn generate_validation(
  schema: JsonValue,
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  case schema {
    JsonBool(value) -> Ok(#(SimpleValidation(value), sub_schema))
    JsonObject(obj) -> {
      case dict.is_empty(obj) {
        True -> Ok(#(SimpleValidation(True), sub_schema))
        False -> {
          case dict.get(obj, "type") {
            Ok(JsonString(data_type)) -> {
              use #(node, sub_schema) <- result.try(
                generate_specified_validation(data_type, obj, sub_schema),
              )
              Ok(#(node, sub_schema))
            }
            Ok(JsonArray(data_types)) -> {
              generate_multi_node(data_types, obj, sub_schema)
            }
            Ok(_) -> Error(InvalidSchema(3))
            Error(Nil) -> {
              todo
            }
          }
        }
      }
    }
    _ -> Error(InvalidSchema(4))
  }
}

fn generate_multi_node(
  data_types: List(JsonValue),
  obj: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use multi_node <- result.try(
    list.try_map(data_types, fn(data_type) {
      case data_type {
        JsonString(data_type) -> {
          use #(node, sub_schema) <- result.try(generate_specified_validation(
            data_type,
            obj,
            sub_schema,
          ))
          Ok(#(node, sub_schema))
        }
        _ -> Error(InvalidSchema(5))
      }
    }),
  )
  // todo Schema merging
  Ok(#(MultiNode(list.map(multi_node, fn(n) { n.0 })), sub_schema))
}

fn generate_specified_validation(
  data_type: String,
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  case data_type {
    "string" -> {
      generate_string_validation(dict, sub_schema)
    }
    _ -> todo
  }
}

fn generate_string_validation(
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use props <- result.try(
    list.try_map(string_properties, fn(prop) {
      use valid_prop <- result.try(prop.1(prop.0, dict))

      case valid_prop {
        Some(valid_prop) -> {
          use final_fn <- result.try(prop.2(valid_prop))
          Ok(Some(final_fn))
        }
        None -> Ok(None)
      }
    }),
  )

  Ok(#(
    StringNode(
      props
      |> list.filter_map(fn(prop) {
        case prop {
          Some(prop) -> Ok(prop)
          None -> Error(Nil)
        }
      }),
    ),
    sub_schema,
  ))
}

/// Property retrieval
fn get_int_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(Some(val), _, _)) -> {
      Ok(Some(IntProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

fn get_float_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _)) -> {
      Ok(Some(FloatProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

fn get_number_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonNumber(_, Some(val), _)) -> {
      Ok(Some(NumberProperty(property, None, Some(val))))
    }
    Ok(JsonNumber(Some(val), _, _)) -> {
      Ok(Some(NumberProperty(property, Some(val), None)))
    }
    Ok(_) -> Error(InvalidSchema(6))
    _ -> Ok(None)
  }
}

fn get_string_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  case dict.get(dict, property) {
    Ok(JsonString(val)) -> {
      Ok(Some(StringProperty(property, val)))
    }
    Ok(_) -> Error(InvalidSchema(7))
    _ -> Ok(None)
  }
}

fn get_pattern_property(
  property: String,
  dict: Dict(String, JsonValue),
) -> Result(Option(ValidationProperty), InvalidEntry) {
  use pattern <- result.try(get_string_property(property, dict))
  io.debug(pattern)
  case pattern {
    Some(StringProperty(_, regex_str)) -> {
      case
        regex.compile(
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

/// String validation
const string_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(ValidationProperty), InvalidEntry),
    fn(ValidationProperty) ->
      Result(fn(String) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry),
  ),
) = [
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
    StringProperty(_, value) -> {
      Ok(fn(v) { None })
    }
    _ -> Error(InvalidSchema(13))
  }
}

/// Perform validation
fn do_validate(json: String, schema: Schema) -> #(Bool, List(InvalidEntry)) {
  case parser.parse(json) {
    Error(err) -> #(False, [InvalidJson(err)])
    Ok(json) -> {
      validate_node(json, schema.validation, schema.sub_schema)
    }
  }
}

fn validate_node(
  node: JsonValue,
  with validation_node: ValidationNode,
  and sub_schema: Dict(String, Schema),
) -> #(Bool, List(InvalidEntry)) {
  case validation_node {
    StringNode(props) -> {
      validate_string(node, props)
    }
    SimpleValidation(True) -> {
      #(True, [])
    }
    SimpleValidation(False) -> {
      #(False, [FalseSchema])
    }
    MultiNode(v_nodes) -> {
      case
        list.fold_until(v_nodes, [], fn(errors, v_node) {
          case validate_node(node, v_node, sub_schema) {
            #(True, _) -> Stop([])
            #(False, err) -> Continue(list.append(err, errors))
          }
        })
      {
        [] -> #(True, [])
        errors -> {
          // Filtering the invalid data types should remove
          // any nodes that type didn't match and keep the node type
          // that matched and its error
          #(
            False,
            list.filter(errors, fn(err) {
              case err {
                InvalidDataType(_) -> False
                _ -> True
              }
            }),
          )
        }
      }
    }
  }
}

fn validate_string(
  node: JsonValue,
  properties: List(fn(String) -> Option(fn(JsonValue) -> InvalidEntry)),
) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonString(str) -> {
      let result =
        list.try_each(properties, fn(validate) {
          case validate(str) {
            Some(e) -> Error(e)
            None -> Ok(Nil)
          }
        })
      case result {
        Ok(Nil) -> #(True, [])
        Error(err) -> #(False, [err(node)])
      }
    }
    _ -> #(False, [InvalidDataType(node)])
  }
}
// fn validate_string_property(str: String, prop: ValidationProperty) {
//   case prop {
//     Int
//   }
// }
