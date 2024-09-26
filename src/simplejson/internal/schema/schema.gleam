import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import simplejson/internal/parser
import simplejson/internal/schema/properties/number.{int_properties}
import simplejson/internal/schema/properties/string.{string_properties}
import simplejson/internal/schema/types.{
  type InvalidEntry, type Schema, type ValidationNode, BooleanNode,
  InvalidDataType, InvalidSchema, MultiNode, NullNode, Number, NumberNode,
  Schema, SimpleValidation, StringNode,
}
import simplejson/internal/schema/validator
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonObject, JsonString,
}

import gleam/dict.{type Dict}
import gleam/option.{None, Some}

pub fn validate(json: String, schema: String) -> #(Bool, List(InvalidEntry)) {
  case generate_schema(schema) {
    Error(_) -> #(False, [InvalidSchema(1)])
    Ok(schema) -> validator.do_validate(json, schema)
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
