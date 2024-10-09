import simplejson/internal/schema/properties/propertyvalues.{type PropertyValue}
import simplejson/jsonvalue.{type JsonValue, type ParseError}

pub type InvalidEntry {
  InvalidEntry(node: JsonValue)
  FalseSchema
  InvalidSchema(p: Int)
  InvalidJson(ParseError)
  InvalidDataType(node: JsonValue)
  NotMatchEnum(node: JsonValue)
  FailedProperty(prop: PropertyValue, value: JsonValue)
}
