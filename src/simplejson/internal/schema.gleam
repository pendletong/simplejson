import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regex.{Options}
import gleam/result
import gleam/string
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, JsonArray, JsonBool, JsonNull, JsonNumber,
  JsonObject, JsonString,
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

pub opaque type Number {
  Number(int: Option(Int), float: Option(Float))
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
  NumberNode(
    properties: List(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry)),
  )
  BooleanNode
  NullNode
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
    "integer" -> {
      generate_int_validation(dict, sub_schema)
    }
    "number" -> {
      generate_number_validation(dict, sub_schema)
    }
    "boolean" -> Ok(#(BooleanNode, sub_schema))
    "null" -> Ok(#(NullNode, sub_schema))
    _ -> todo
  }
}

fn generate_number_validation(
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use props <- result.try(
    list.try_map(int_properties, fn(prop) {
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
    NumberNode(
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

fn generate_int_validation(
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use props <- result.try(
    list.try_map(int_properties, fn(prop) {
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
    NumberNode([
      fn(num) {
        case num {
          Number(Some(i), _) -> None
          Number(_, Some(f)) -> {
            case f == int.to_float(float.truncate(f)) {
              True -> None
              False -> Some(fn(json_value) { InvalidDataType(json_value) })
            }
          }
          Number(None, None) -> Some(fn(_) { InvalidSchema(16) })
        }
      },
      ..props
      |> list.filter_map(fn(prop) {
        case prop {
          Some(prop) -> Ok(prop)
          None -> Error(Nil)
        }
      })
    ]),
    sub_schema,
  ))
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

/// Int validation
const int_properties = [
  #("multipleOf", get_number_property, number_multiple_of),
  #("minimum", get_number_property, number_minimum),
  #("exclusiveMinimum", get_number_property, number_exclusiveminimum),
  #("maximum", get_number_property, number_maximum),
  #("exclusiveMaximum", get_number_property, number_exclusivemaximum),
]

fn number_minimum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 >= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusiveminimum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 > i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_maximum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 < i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusivemaximum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 <= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_multiple_of(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(_), None -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, _))
              Error(err) -> Some(fn(_) { err })
            }
          }
          None, Some(_) -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, _))
              Error(err) -> Some(fn(_) { err })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn is_multiple(num: Number, of: Number) -> Result(Bool, InvalidEntry) {
  case num {
    Number(Some(i1), None) -> {
      case of {
        Number(Some(i2), None) -> {
          Ok(i1 % i2 == 0)
        }
        Number(None, Some(f2)) -> {
          let f1 = int.to_float(i1)
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        _ -> Error(InvalidSchema(17))
      }
    }
    Number(None, Some(f1)) -> {
      case of {
        Number(Some(i2), None) -> {
          let f2 = int.to_float(i2)
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        Number(None, Some(f2)) -> {
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        _ -> Error(InvalidSchema(17))
      }
    }
    _ -> Error(InvalidSchema(19))
  }
}

/// String validation
const string_properties = [
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
    NumberNode(props) -> {
      validate_number(node, props)
    }
    BooleanNode -> {
      validate_boolean(node)
    }
    NullNode -> {
      validate_null(node)
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

fn validate_number(
  node: JsonValue,
  properties: List(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry)),
) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonNumber(i, f, _) -> {
      let result =
        list.try_each(properties, fn(validate) {
          case validate(Number(i, f)) {
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

fn validate_boolean(node: JsonValue) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonBool(_) -> #(True, [])
    _ -> #(False, [InvalidDataType(node)])
  }
}

fn validate_null(node: JsonValue) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonNull -> #(True, [])
    _ -> #(False, [InvalidDataType(node)])
  }
}
// fn validate_string_property(str: String, prop: ValidationProperty) {
//   case prop {
//     Int
//   }
// }
