//// SimpleJSON
//// 
//// Basic JSON library for Gleam

import simplejson/internal/parser
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, type ParseError}

/// Parse a given string into a JsonValue Result
/// Or return Error if unable. This currently returns
/// Error(Nil) but will be extended in later versions to
/// give more detailed error information
/// 
/// ## Examples
///
/// ```gleam
/// parse("{\"a\":123,\"b\":[true, false]}")
/// // -> Ok(JsonObject(dict.from_list([#("a", JsonNumber(Some(123), None, Some("123"))), #("b", JsonArray([JsonBool(True), JsonBool(False)]))])))
/// ```
/// 
/// ```gleam
/// parse("[1,2,3]")
/// // -> Ok(JsonArray([JsonNumber(Some(1), None, Some("1")), JsonNumber(Some(2), None, Some("2")), JsonNumber(Some(3), None, Some("3"))]))
/// ```
/// 
pub fn parse(json: String) -> Result(JsonValue, ParseError) {
  parser.parse(json)
}

/// Convert a given JsonValue into a String
/// 
/// ##Example
/// 
/// ```gleam
/// to_string(JsonArray([JsonNumber(Some(1), None, Some("1")), JsonNumber(Some(2), None, Some("2")), JsonNumber(Some(3), None, Some("3"))]))
/// // -> "[1,2,3]"
/// ```
/// 
pub fn to_string(json: JsonValue) -> String {
  stringify.to_string(json)
}
