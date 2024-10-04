import gleam/option.{type Option}

import simplejson/jsonvalue.{type JsonValue, type ParseError}

import gleam/dict.{type Dict}

pub type Number {
  Number(int: Option(Int), float: Option(Float))
}

pub type ValidationProperty {
  BooleanProperty(name: String, value: Bool)
  StringProperty(name: String, value: String)
  IntProperty(name: String, value: Int)
  FloatProperty(name: String, value: Float)
  NumberProperty(name: String, value: Option(Int), or_value: Option(Float))
  ObjectProperty(name: String, value: Dict(String, JsonValue))
}

pub type Combination {
  All
  AllBreakAfterFirst
  Any
  One
  None
}

pub type ValidationNode {
  SimpleValidation(valid: Bool)
  MultiNode(validations: List(ValidationNode), combination: Combination)
  PropertiesNode(properties: List(fn(JsonValue) -> Option(InvalidEntry)))
  StringNode
  NumberNode
  ArrayNode(
    items: Option(ValidationNode),
    prefix_items: Option(List(ValidationNode)),
  )
  ContainsNode(item: ValidationNode, max: Option(Int), min: Option(Int))
  EnumNode(value: List(JsonValue))
  BooleanNode
  NullNode
}

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
    validation: ValidationNode,
  )
}

pub type InvalidEntry {
  InvalidEntry(node: JsonValue)
  FalseSchema
  InvalidSchema(p: Int)
  InvalidJson(ParseError)
  InvalidDataType(node: JsonValue)
  NotMatchEnum(node: JsonValue)
  FailedProperty(prop: ValidationProperty, value: JsonValue)
}
