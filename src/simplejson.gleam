//// SimpleJSON
////
//// Basic JSON library for Gleam.
//// To be used for simple conversion from string to a basic JSON structure
//// and to then output that as a string again.

import simplejson/internal/parser
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, type ParseError}

/// Parse a given string into a JsonValue Result.
/// Or return Error if unable.
///
/// Thie returns a useful description
/// of the parse failure utilising the `ParseError` types.
///
/// The error will either be `UnexpectedEnd` or a specific reason
/// containing the character/value that failed to parse, a context which
/// contains the surrounding up to 10 characters and the character
/// index of the failure point
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
/// ```gleam
/// parse("[1,2,3,]")
/// // -> Error(UnexpectedCharacter("]", ",2,3,]", 7))
/// ```
pub fn parse(json: String) -> Result(JsonValue, ParseError) {
  parser.parse(json)
}

/// Convert a given JsonValue into a String
///
/// ## Examples
///
/// ```gleam
/// to_string(JsonArray([JsonNumber(Some(1), None, Some("1")), JsonNumber(Some(2), None, Some("2")), JsonNumber(Some(3), None, Some("3"))]))
/// // -> "[1,2,3]"
/// ```
///
pub fn to_string(json: JsonValue) -> String {
  stringify.to_string(json)
}
