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

pub type ParseError {
  UnexpectedCharacter(char: String, pos: Int)
  Unknown
  UnexpectedEnd
  InvalidEscapeCharacter(char: String, pos: Int)
  InvalidCharacter(char: String, pos: Int)
  InvalidHex(hex: String, pos: Int)
  InvalidNumber(num: String, pos: Int)
}
