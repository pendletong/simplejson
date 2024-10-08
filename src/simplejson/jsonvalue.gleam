import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type JsonMetaData {
  JsonMetaData(start_position: Int, end_position: Int)
  NoMD
}

/// Type that wraps all JSON value types
pub type JsonValue {
  /// Wraps a string value
  JsonString(metadata: JsonMetaData, str: String)
  /// Wraps a number value and stores an int or float depending
  /// on the input type.
  /// Also the original is stored as a String if the JSON has been parsed
  /// from text
  JsonNumber(
    metadata: JsonMetaData,
    int: Option(Int),
    float: Option(Float),
    original: Option(String),
  )
  /// Wraps a boolean value
  JsonBool(metadata: JsonMetaData, bool: Bool)
  /// Indicates a null value
  JsonNull(metadata: JsonMetaData)
  /// Wraps an array value
  JsonArray(metadata: JsonMetaData, array: Dict(Int, JsonValue))
  /// Wraps an object value
  JsonObject(metadata: JsonMetaData, object: Dict(String, JsonValue))
}

pub type ParseError {
  UnexpectedCharacter(char: String, context: String, pos: Int)
  Unknown
  UnexpectedEnd
  InvalidEscapeCharacter(char: String, context: String, pos: Int)
  InvalidCharacter(char: String, context: String, pos: Int)
  InvalidHex(hex: String, context: String, pos: Int)
  InvalidGrapheme(hex: String, context: String, pos: Int)
  InvalidNumber(num: String, context: String, pos: Int)
  NestingDepth(num_levels: Int)
}

pub type JsonPathError {
  ParseError(context: String)
  MissingRoot
  IndexOutOfRange(i: Int)
  NoMatch
  FunctionError
  ComparisonError
  InvalidJsonPath
  PathNotFound
}
