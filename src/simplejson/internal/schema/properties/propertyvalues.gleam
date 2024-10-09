import gleam/dict.{type Dict}
import gleam/option.{type Option}
import simplejson/jsonvalue.{type JsonValue}

pub type PropertyValue {
  BooleanValue(name: String, value: Bool)
  StringValue(name: String, value: String)
  IntValue(name: String, value: Int)
  FloatValue(name: String, value: Float)
  NumberValue(name: String, value: Option(Int), or_value: Option(Float))
  ObjectValue(name: String, value: Dict(String, JsonValue))
  ListValue(name: String, value: List(PropertyValue))
}
