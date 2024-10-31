import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// Type that wraps all JSON value types
pub type JsonValue {
  /// Wraps a string value
  JsonString(str: String)
  /// Wraps a number value and stores an int or float depending
  /// on the input type.
  /// Also the original is stored as a String if the JSON has been parsed
  /// from text
  JsonNumber(int: Option(Int), float: Option(Float), original: Option(String))
  /// Wraps a boolean value
  JsonBool(bool: Bool)
  /// Indicates a null value
  JsonNull
  /// Wraps an array value
  JsonArray(Dict(Int, JsonValue))
  /// Wraps an object value
  JsonObject(Dict(String, JsonValue))
}

pub type ParseError {
  UnexpectedCharacter(char: String, context: String, pos: Int)
  Unknown
  UnexpectedEnd
  InvalidEscapeCharacter(char: String, context: String, pos: Int)
  InvalidCharacter(char: String, context: String, pos: Int)
  InvalidHex(hex: String, context: String, pos: Int)
  InvalidNumber(num: String, context: String, pos: Int)
  NestingDepth(num_levels: Int)
}
