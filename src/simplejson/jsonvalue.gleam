import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type JsonValue {
  JsonString(str: String)
  JsonNumber(int: Option(Int), float: Option(Float), original: Option(String))
  JsonBool(bool: Bool)
  JsonNull
  JsonArray(Dict(Int, JsonValue))
  JsonObject(Dict(String, JsonValue))
}

pub type ParseError {
  UnexpectedCharacter(char: String, rest: String, pos: Int)
  Unknown
  UnexpectedEnd
  InvalidEscapeCharacter(char: String, rest: String, pos: Int)
  InvalidCharacter(char: String, rest: String, pos: Int)
  InvalidHex(hex: String, rest: String, pos: Int)
  InvalidNumber(num: String, rest: String, pos: Int)
  NestingDepth(num_levels: Int)
}
