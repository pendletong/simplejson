import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/option.{type Option, Some}

pub type JsonMetaData {
  JsonMetaData(start_position: Int, end_position: Int)
}

/// Type that wraps all JSON value types
pub type JsonValue {
  /// Wraps a string value
  JsonString(str: String, metadata: Option(JsonMetaData))
  /// Wraps a number value and stores an int or float depending
  /// on the input type.
  /// Also the original is stored as a String if the JSON has been parsed
  /// from text
  JsonNumber(
    int: Option(Int),
    float: Option(Float),
    metadata: Option(JsonMetaData),
  )
  /// Wraps a boolean value
  JsonBool(bool: Bool, metadata: Option(JsonMetaData))
  /// Indicates a null value
  JsonNull(metadata: Option(JsonMetaData))
  /// Wraps an array value
  JsonArray(array: Dict(Int, JsonValue), metadata: Option(JsonMetaData))
  /// Wraps an object value
  JsonObject(object: Dict(String, JsonValue), metadata: Option(JsonMetaData))
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
  InvalidInt(int: String)
  InvalidFloat(float: String)
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

pub fn get_int_from_number(json: JsonValue) -> Result(Int, Nil) {
  case json {
    JsonNumber(Some(i), _, _) -> Ok(i)
    JsonNumber(_, Some(f), _) -> {
      let truncated = float.truncate(f)
      case int.to_float(truncated) == f {
        True -> Ok(truncated)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
