import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import simplejson/internal/parser
import simplejson/internal/schema/properties/array.{array_properties}
import simplejson/internal/schema/properties/number.{int_properties}
import simplejson/internal/schema/properties/string.{string_properties}
import simplejson/internal/schema/types.{
  type InvalidEntry, type Schema, type ValidationNode, Any, ArrayNode,
  BooleanNode, InvalidDataType, InvalidSchema, MultiNode, NullNode, NumberNode,
  Schema, SimpleValidation, StringNode,
}
import simplejson/internal/schema/validator
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNumber, JsonObject, JsonString,
}

import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}

pub fn validate(json: String, schema: String) -> #(Bool, List(InvalidEntry)) {
  case generate_schema(schema) {
    Error(err) -> #(False, [err])
    Ok(schema) -> validator.do_validate(json, schema)
  }
}

fn generate_schema(schema: String) -> Result(Schema, InvalidEntry) {
  use schema <- result.try(
    parser.parse(schema) |> result.replace_error(InvalidSchema(2)),
  )

  case generate_validation(schema, dict.new(), None) {
    Ok(#(validator, sub_schema)) ->
      Ok(Schema(None, None, schema, validator, sub_schema))
    Error(err) -> Error(err)
  }
  |> io.debug
}

fn generate_validation(
  schema: JsonValue,
  sub_schema: Dict(String, Schema),
  root: Option(ValidationNode),
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
                generate_specified_validation(data_type, obj, sub_schema, root),
              )
              Ok(#(node, sub_schema))
            }
            Ok(JsonArray(data_types)) -> {
              generate_multi_node(data_types, obj, sub_schema, root)
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
  root: Option(ValidationNode),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use multi_node <- result.try(
    list.try_map(data_types, fn(data_type) {
      case data_type {
        JsonString(data_type) -> {
          use #(node, sub_schema) <- result.try(generate_specified_validation(
            data_type,
            obj,
            sub_schema,
            root,
          ))
          Ok(#(node, sub_schema))
        }
        _ -> Error(InvalidSchema(5))
      }
    }),
  )
  // todo Schema merging
  Ok(#(MultiNode(list.map(multi_node, fn(n) { n.0 }), Any), sub_schema))
}

fn generate_specified_validation(
  data_type: String,
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
  root: Option(ValidationNode),
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
    "array" -> {
      generate_array_validation(dict, sub_schema, root)
    }
    "boolean" -> Ok(#(BooleanNode, sub_schema))
    "null" -> Ok(#(NullNode, sub_schema))
    _ -> todo
  }
}

fn generate_array_validation(
  dict: Dict(String, JsonValue),
  sub_schema: Dict(String, Schema),
  root: Option(ValidationNode),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  use val_nodes <- result.try(case dict.get(dict, "items") {
    Ok(json) -> {
      use #(vn, sub) <- result.try(generate_validation(json, sub_schema, root))

      Ok(#([vn], dict.merge(sub_schema, sub)))
    }
    Error(_) -> {
      Ok(#([], sub_schema))
    }
  })

  use props <- result.try(
    list.try_map(array_properties, fn(prop) {
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

  let props =
    props
    |> list.filter_map(fn(prop) {
      case prop {
        Some(prop) -> Ok(prop)
        None -> Error(Nil)
      }
    })

  Ok(#(ArrayNode(props, [SimpleValidation(True)], root), val_nodes.1))
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
          JsonNumber(Some(_), _, _) -> None
          JsonNumber(_, Some(f), _) -> {
            case f == int.to_float(float.truncate(f)) {
              True -> None
              False -> Some(InvalidDataType(num))
            }
          }
          _ -> Some(InvalidSchema(16))
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
