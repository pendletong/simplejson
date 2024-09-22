import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type JsonValue {
  JsonString(str: String)
  JsonNumber(int: Option(Int), float: Option(Float), original: Option(String))
  JsonBool(bool: Bool)
  JsonNull
  JsonArray(List(JsonValue))
  JsonObject(Dict(String, JsonValue))
}
