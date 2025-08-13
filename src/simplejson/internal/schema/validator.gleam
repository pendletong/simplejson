import gleam/dict.{type Dict}
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import simplejson/internal/parser
import simplejson/internal/schema/types.{
  type InvalidEntry, type Number, type Schema, type ValidationNode, ArrayNode,
  BooleanNode, FalseSchema, InvalidDataType, InvalidJson, MultiNode, NullNode,
  Number, NumberNode, Schema, SimpleValidation, StringNode,
}
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonString,
}

pub fn do_validate(json: String, schema: Schema) -> #(Bool, List(InvalidEntry)) {
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
    ArrayNode(props, _validators) -> {
      validate_array(node, props)
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
          let errors =
            list.filter(errors, fn(err) {
              case err {
                InvalidDataType(_) -> False
                _ -> True
              }
            })

          // If there are no errors then the issue must be
          // data type matching so return that error
          let errors = case errors {
            [] -> [InvalidDataType(node)]
            _ -> errors
          }
          #(False, errors)
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

fn validate_array(
  node: JsonValue,
  properties: List(fn(List(JsonValue)) -> Option(fn(JsonValue) -> InvalidEntry)),
) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonArray(l) -> {
      #(True, [])
    }
    _ -> #(False, [InvalidDataType(node)])
  }
}
