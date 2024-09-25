import gleam/bool
import gleam/dict
import gleam/option.{type Option, None}
import gleam/result
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, JsonBool, JsonObject,
}

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
  )
}

pub fn validate(json: String, schema: String) -> #(Bool, List(InvalidEntry)) {
  case generate_schema(schema) {
    Error(_) -> #(False, [InvalidSchema])
    Ok(schema) -> do_validate(json, schema)
  }
}

fn generate_schema(schema: String) -> Result(Schema, Nil) {
  use schema <- result.try(parser.parse(schema) |> result.replace_error(Nil))

  Ok(Schema(None, None, schema))
}

fn do_validate(json: String, schema: Schema) -> #(Bool, List(InvalidEntry)) {
  case parser.parse(json) {
    Error(err) -> #(False, [InvalidJson(err)])
    Ok(json) -> {
      use <- bool.guard(
        when: schema.schema == JsonObject(dict.from_list([])),
        return: #(True, []),
      )
      use <- bool.guard(
        when: schema.schema == JsonBool(True),
        return: #(True, []),
      )
      use <- bool.guard(
        when: schema.schema == JsonBool(False),
        return: #(False, [FalseSchema]),
      )
      #(False, [InvalidEntry(json)])
    }
  }
}

type StringType {
  StringType(
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
}
