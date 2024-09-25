import gleam/dict.{type Dict}
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None}
import gleam/result
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, JsonBool, JsonObject, JsonString,
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

pub opaque type ValidationNode {
  SimpleValidation(valid: Bool)
  MultiNode(List(ValidationNode))
  StringNode(
    min_length: Option(Int),
    max_length: Option(Int),
    pattern: Option(String),
    format: Option(String),
  )
}

pub type InvalidEntry {
  InvalidEntry(node: JsonValue)
  FalseSchema
  InvalidSchema
  InvalidJson(ParseError)
  InvalidDataType(node: JsonValue)
}

pub fn validate(json: String, schema: String) -> #(Bool, List(InvalidEntry)) {
  case generate_schema(schema) {
    Error(_) -> #(False, [InvalidSchema])
    Ok(schema) -> do_validate(json, schema)
  }
}

fn generate_schema(schema: String) -> Result(Schema, InvalidEntry) {
  use schema <- result.try(
    parser.parse(schema) |> result.replace_error(InvalidSchema),
  )

  case generate_validation(schema, dict.new()) {
    Ok(#(validator, sub_schema)) ->
      Ok(Schema(None, None, schema, validator, sub_schema))
    Error(err) -> Error(err)
  }
}

fn generate_validation(
  schema: JsonValue,
  sub_schema: Dict(String, Schema),
) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {
  case schema {
    JsonBool(value) -> Ok(#(SimpleValidation(value), sub_schema))
    JsonObject(dict) -> {
      case dict.is_empty(dict) {
        True -> Ok(#(SimpleValidation(True), sub_schema))
        False -> {
          todo
        }
      }
    }
    _ -> Error(InvalidSchema)
  }
}

// fn generate_object_validation(
//   dict: Dict(String, JsonValue),
//   sub_schema: Dict(String, Schema),
// ) -> Result(#(ValidationNode, Dict(String, Schema)), InvalidEntry) {

// }

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
    StringNode(min, max, pattern, format) -> {
      validate_string(node, min, max, pattern, format)
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
  min_length: Option(Int),
  max_length: Option(Int),
  pattern: Option(String),
  format: Option(String),
) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonString(_str) -> {
      #(True, [])
    }
    _ -> #(False, [InvalidDataType(node)])
  }
}
