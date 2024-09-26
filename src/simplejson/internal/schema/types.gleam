import gleam/option.{type Option}

import simplejson/jsonvalue.{type JsonValue, type ParseError}

import gleam/dict.{type Dict}

pub type Number {
  Number(int: Option(Int), float: Option(Float))
}

pub type ValidationProperty {
  StringProperty(name: String, value: String)
  IntProperty(name: String, value: Int)
  FloatProperty(name: String, value: Float)
  NumberProperty(name: String, value: Option(Int), or_value: Option(Float))
}

pub type ValidationNode {
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

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
    validation: ValidationNode,
    sub_schema: Dict(String, Schema),
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
