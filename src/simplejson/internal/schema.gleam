import gleam/bool
import gleam/dict.{type Dict}
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
          Error(InvalidSchema)
        }
      }
    }
    _ -> Error(InvalidSchema)
  }
}

fn do_validate(json: String, schema: Schema) -> #(Bool, List(InvalidEntry)) {
  case parser.parse(json) {
    Error(err) -> #(False, [InvalidJson(err)])
    Ok(json) -> {
      validate_node(json, schema.validation, schema.sub_schema)
      //   use <- bool.guard(
      //     when: schema.schema == JsonObject(dict.from_list([])),
      //     return: #(True, []),
      //   )
      //   use <- bool.guard(
      //     when: schema.schema == JsonBool(True),
      //     return: #(True, []),
      //   )
      //   use <- bool.guard(
      //     when: schema.schema == JsonBool(False),
      //     return: #(False, [FalseSchema]),
      //   )
      //   #(False, [InvalidEntry(json)])
      //   validate_node()
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
