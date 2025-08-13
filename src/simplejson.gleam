//// SimpleJSON
////
//// Basic JSON library for Gleam.
//// To be used for simple conversion from string to a basic JSON structure
//// and to then output that as a string again.

import gleam/dict
import gleam/option.{None}
import simplejson/internal/jsonpath.{type JsonPath}
import simplejson/internal/parser
import simplejson/internal/pointer
import simplejson/internal/query
import simplejson/internal/stringify
import simplejson/jsonvalue.{
  type JsonPathError, type JsonValue, type ParseError, JsonArray, JsonBool,
  JsonNull, JsonNumber, JsonObject, JsonString,
}

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
  case parser.parse(json) {
    Ok(json) -> Ok(strip_metadata(json))
    Error(_) as err -> err
  }
}

fn strip_metadata(json: JsonValue) -> JsonValue {
  case json {
    JsonNull(_) -> JsonNull(None)
    JsonBool(b, _) -> JsonBool(b, None)
    JsonString(s, _) -> JsonString(s, None)
    JsonNumber(i, f, o, _) -> JsonNumber(i, f, o, None)
    JsonArray(l, _) ->
      JsonArray(dict.map_values(l, fn(_k, v) { strip_metadata(v) }), None)
    JsonObject(d, _) ->
      JsonObject(dict.map_values(d, fn(_k, v) { strip_metadata(v) }), None)
  }
}

pub fn parse_with_metadata(json: String) -> Result(JsonValue, ParseError) {
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

/// Simple jsonpath style querying method
///
/// A simple **.** separated list of path elements to take
/// - names are as-is
/// - indexes are prefixes by #
/// - consecutive separators are ignored
/// - e.g. key1.#3...nextkey
///
///
/// ## Examples
///
/// ```Gleam
/// let assert Ok(json) = simplejson.parse("{\"a\":[1,2,{\"b\":123}]}")
/// simplejson.jsonpath(json, "a.#2.b")
/// // -> JsonNumber(Some(123), None, Some("123"))
/// ```
pub fn jsonpath(
  json: JsonValue,
  jsonpath: String,
) -> Result(JsonValue, JsonPathError) {
  pointer.jsonpath(json, jsonpath)
}

/// Converts the passed string into a query type to be used in the query function
///
/// This parses based on RFC9535 (https://www.rfc-editor.org/rfc/rfc9535)
///
/// ## Examples
///
/// ```Gleam
/// let assert Ok(path) = simplejson.to_path("$[1]")
/// // -> [Child([Index(1)])]
/// ```
pub fn to_path(str: String) -> Result(JsonPath, JsonPathError) {
  jsonpath.parse_path(str)
}

/// Takes the provided path and json and returns a Json Array of results
///
/// This executes based on RFC9535 (https://www.rfc-editor.org/rfc/rfc9535)
///
/// ## Examples
///
/// ```Gleam
/// let assert Ok(path) = simplejson.to_path("$[1]")
/// let assert Ok(json) = simplejson.parse("[1,2,3]")
/// simplejson.to_string(simplejson.query(json, path))
/// // -> [2]
/// ```
pub fn query(json: JsonValue, path: JsonPath) -> JsonValue {
  query.query(json, path, json)
}
