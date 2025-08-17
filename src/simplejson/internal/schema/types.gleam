import gleam/dict.{type Dict}
import gleam/option.{type Option}
import simplejson/jsonvalue.{type JsonValue}

import simplejson/internal/schema/error.{type InvalidEntry}

pub type Number {
  Number(int: Option(Int), float: Option(Float))
}

pub type Combination {
  All
  AllBreakAfterFirst
  Any
  AnyFail
  One
  None
}

pub type ValidationNode {
  SimpleValidation(valid: Bool)
  IfNode(check: ValidationNode, then: ValidationNode)
  MultiNode(validations: List(ValidationNode), combination: Combination)
  PropertiesNode(properties: List(fn(JsonValue) -> Option(InvalidEntry)))
  StringNode
  NumberNode
  ArrayNode(
    items: Option(ValidationNode),
    prefix_items: Option(List(ValidationNode)),
  )
  ObjectNode(items: Option(Dict(String, ValidationNode)))
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
