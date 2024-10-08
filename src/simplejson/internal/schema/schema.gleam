import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import simplejson
import simplejson/internal/schema/properties/array.{array_properties}
import simplejson/internal/schema/properties/number.{int_properties}
import simplejson/internal/schema/properties/string.{string_properties}
import simplejson/internal/schema/types.{
  type InvalidEntry, type Schema, type ValidationNode, type ValidationProperty,
  All, AllBreakAfterFirst, Any, ArrayNode, BooleanNode, ContainsNode, EnumNode,
  InvalidDataType, InvalidJson, InvalidSchema, MultiNode, NullNode, NumberNode,
  PropertiesNode, Schema, SimpleValidation, StringNode,
}
import simplejson/internal/schema/validator
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNumber, JsonObject, JsonString,
}

import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}

pub fn validate(
  json: String,
  schema: String,
) -> Result(Bool, List(InvalidEntry)) {
  use json <- result.try(
    simplejson.parse(json) |> result.map_error(fn(e) { [InvalidJson(e)] }),
  )
  case generate_schema(schema) {
    Error(err) -> Error([err])
    Ok(schema) -> validator.do_validate(json, schema)
  }
}

pub fn validate_json(
  schema: JsonValue,
  json: JsonValue,
) -> Result(Bool, List(InvalidEntry)) {
  case generate_schema_from_json(schema) {
    Error(err) -> Error([err])
    Ok(schema) -> validator.do_validate(json, schema)
  }
}

fn generate_schema(schema: String) -> Result(Schema, InvalidEntry) {
  use schema <- result.try(
    simplejson.parse(schema) |> result.replace_error(InvalidSchema(2)),
  )

  generate_schema_from_json(schema)
}

fn generate_schema_from_json(schema: JsonValue) -> Result(Schema, InvalidEntry) {
  case generate_validation(schema, None) {
    Ok(validator) -> Ok(Schema(None, None, schema, validator))
    Error(err) -> Error(err)
  }
  // |> io.debug
}

fn generate_validation(
  schema: JsonValue,
  root: Option(ValidationNode),
) -> Result(ValidationNode, InvalidEntry) {
  case schema {
    JsonBool(_, value) -> Ok(SimpleValidation(value))
    JsonObject(_, obj) -> {
      case dict.is_empty(obj) {
        True -> Ok(SimpleValidation(True))
        False -> {
          use type_node <- result.try(case dict.get(obj, "type") {
            Ok(JsonString(_, data_type)) -> {
              use node <- result.try(generate_specified_validation(
                data_type,
                obj,
                root,
              ))
              Ok(Some(node))
            }
            Ok(JsonArray(_, data_types)) -> {
              generate_multi_node(data_types, obj, root)
              |> result.map(fn(n) { Some(n) })
            }
            Ok(_) -> Error(InvalidSchema(3))
            Error(Nil) -> {
              Ok(None)
            }
          })

          use enum_node <- result.try(case dict.get(obj, "enum") {
            Ok(JsonArray(_, values)) -> {
              Ok(Some(EnumNode(values)))
            }
            Ok(_) -> Error(InvalidSchema(23))
            Error(_) -> Ok(None)
          })

          Ok(MultiNode(combine_nodes([type_node, enum_node]), All))
        }
      }
    }
    _ -> Error(InvalidSchema(4))
  }
}

fn combine_nodes(nodes: List(Option(ValidationNode))) -> List(ValidationNode) {
  list.filter_map(nodes, fn(n) {
    case n {
      Some(n) -> Ok(n)
      _ -> Error(Nil)
    }
  })
}

fn generate_multi_node(
  data_types: List(JsonValue),
  obj: Dict(String, JsonValue),
  root: Option(ValidationNode),
) -> Result(ValidationNode, InvalidEntry) {
  use multi_node <- result.try(
    list.try_map(data_types, fn(data_type) {
      case data_type {
        JsonString(_, data_type) -> {
          use node <- result.try(generate_specified_validation(
            data_type,
            obj,
            root,
          ))
          Ok(node)
        }
        _ -> Error(InvalidSchema(5))
      }
    }),
  )
  Ok(MultiNode(multi_node, Any))
}

fn generate_specified_validation(
  data_type: String,
  dict: Dict(String, JsonValue),
  root: Option(ValidationNode),
) -> Result(ValidationNode, InvalidEntry) {
  case data_type {
    "string" -> {
      generate_string_validation(dict)
    }
    "integer" -> {
      generate_int_validation(dict)
    }
    "number" -> {
      generate_number_validation(dict)
    }
    "array" -> {
      generate_array_validation(dict, root)
    }
    "boolean" -> Ok(BooleanNode)
    "null" -> Ok(NullNode)
    "object" -> todo
    _ -> Error(InvalidSchema(34))
  }
}

fn generate_array_validation(
  dict: Dict(String, JsonValue),
  root: Option(ValidationNode),
) -> Result(ValidationNode, InvalidEntry) {
  use items <- result.try(get_meta(dict, root, "items"))

  use prefix_items <- result.try(case dict.get(dict, "prefixItems") {
    Ok(JsonArray(_, l)) -> {
      use val_nodes <- result.try(
        list.try_map(l, fn(i) { generate_validation(i, root) }),
      )
      Ok(val_nodes)
    }
    Ok(_) -> Error(InvalidSchema(31))
    Error(_) -> Ok([])
  })

  use props <- result.try(get_properties(array_properties, dict))
  let prefix_items = case prefix_items {
    [] -> None
    _ -> Some(prefix_items)
  }

  use contains <- result.try(get_meta(dict, root, "contains"))

  let nodes =
    case contains {
      Some(vn) -> [ContainsNode(vn, None, None)]
      None -> []
    }
    |> list.append([ArrayNode(items, prefix_items), PropertiesNode(props)])

  Ok(MultiNode(nodes, AllBreakAfterFirst))
}

fn get_meta(
  dict: Dict(String, JsonValue),
  root: Option(ValidationNode),
  prop_name: String,
) {
  case dict.get(dict, prop_name) {
    Ok(JsonObject(_, _) as json) -> {
      use vn <- result.try(generate_validation(json, root))

      Ok(Some(vn))
    }
    Ok(JsonBool(_, b)) -> Ok(Some(SimpleValidation(b)))
    Ok(_) -> Error(InvalidSchema(30))
    Error(_) -> {
      Ok(None)
    }
  }
}

fn get_properties(
  properties: List(
    #(
      String,
      fn(String, Dict(String, JsonValue)) ->
        Result(Option(ValidationProperty), InvalidEntry),
      fn(ValidationProperty) ->
        Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
    ),
  ),
  dict: Dict(String, JsonValue),
) {
  use props <- result.try(
    list.try_map(properties, fn(prop) {
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
  Ok(
    props
    |> list.filter_map(fn(prop) {
      case prop {
        Some(prop) -> Ok(prop)
        None -> Error(Nil)
      }
    }),
  )
}

fn generate_number_validation(
  dict: Dict(String, JsonValue),
) -> Result(ValidationNode, InvalidEntry) {
  use props <- result.try(get_properties(int_properties, dict))
  Ok(MultiNode([NumberNode, PropertiesNode(props)], AllBreakAfterFirst))
}

fn generate_int_validation(
  dict: Dict(String, JsonValue),
) -> Result(ValidationNode, InvalidEntry) {
  use props <- result.try(get_properties(int_properties, dict))

  Ok(MultiNode(
    [
      NumberNode,
      PropertiesNode([
        fn(num) {
          case num {
            JsonNumber(_, Some(_), _, _) -> None
            JsonNumber(_, _, Some(f), _) -> {
              case f == int.to_float(float.truncate(f)) {
                True -> None
                False -> Some(InvalidDataType(num))
              }
            }
            _ -> Some(InvalidSchema(16))
          }
        },
        ..props
      ]),
    ],
    AllBreakAfterFirst,
  ))
}

fn generate_string_validation(
  dict: Dict(String, JsonValue),
) -> Result(ValidationNode, InvalidEntry) {
  use props <- result.try(get_properties(string_properties, dict))

  Ok(MultiNode([StringNode, PropertiesNode(props)], AllBreakAfterFirst))
}
