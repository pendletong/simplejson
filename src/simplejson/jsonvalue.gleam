import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type JsonMetaData {
  JsonMetaData(start_position: Int, end_position: Int)
  NoMD
}

pub type JsonValue {
  JsonString(metadata: JsonMetaData, str: String)
  JsonNumber(
    metadata: JsonMetaData,
    int: Option(Int),
    float: Option(Float),
    original: Option(String),
  )
  JsonBool(metadata: JsonMetaData, bool: Bool)
  JsonNull(metadata: JsonMetaData)
  JsonArray(metadata: JsonMetaData, List(JsonValue))
  JsonObject(metadata: JsonMetaData, Dict(String, JsonValue))
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
