import gleam/dict
import gleam/option.{None, Some}
import simplejson
import simplejson/jsonvalue.{
  InvalidCharacter, InvalidEscapeCharacter, InvalidHex, InvalidNumber, JsonArray,
  JsonBool, JsonNull, JsonNumber, JsonObject, JsonString, UnexpectedCharacter,
  UnexpectedEnd,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn parse_number_tests() {
  describe("Number Parsing - Successful", [
    it("Zero", fn() {
      simplejson.parse("0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(0), None, Some("0")))
      simplejson.parse("-0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(0), None, Some("-0")))
    }),
    it("Negative", fn() {
      simplejson.parse("-1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-1), None, Some("-1")))
      simplejson.parse("-1.5")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-1.5), Some("-1.5")))
    }),
    it("Exponent", fn() {
      simplejson.parse("1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some("1e2")))
      simplejson.parse("1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(0.01), Some("1e-2")))
      simplejson.parse("1e+2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some("1e2")))
      simplejson.parse("1E2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some("1e2")))
      simplejson.parse("1E-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(0.01), Some("1e-2")))
      simplejson.parse("-1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-100), None, Some("-1e2")))
      simplejson.parse("-1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-0.01), Some("-1e-2")))
    }),
    it("Float", fn() {
      simplejson.parse("0.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(0.1234), Some("0.1234")))
      simplejson.parse("-9876.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-9876.1234), Some("-9876.1234")))
    }),
  ])
}

pub fn parse_array_tests() {
  describe("Array Parsing - Successful", [
    it("Empty Array", fn() {
      simplejson.parse("[]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray([]))
    }),
    it("Array with String", fn() {
      simplejson.parse("[\"a\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray([JsonString("a")]))
    }),
    it("Array with Multiple Strings", fn() {
      simplejson.parse("[\"a\", \"z\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray([JsonString("a"), JsonString("z")]))
    }),
    it("Array with String and Spaces", fn() {
      simplejson.parse(" [ \"a\" ] ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray([JsonString("a")]))
    }),
    it("Array with Int", fn() {
      simplejson.parse("[123]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray([JsonNumber(Some(123), None, Some("123"))]))
    }),
    it("Array with Multiple Ints", fn() {
      simplejson.parse("[999, 111]")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonArray([
          JsonNumber(Some(999), None, Some("999")),
          JsonNumber(Some(111), None, Some("111")),
        ]),
      )
    }),
    it("Array with Float", fn() {
      simplejson.parse("[123.5]")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonArray([JsonNumber(None, Some(123.5), Some("123.5"))]),
      )
    }),
    it("Array with Multiple Floats", fn() {
      simplejson.parse("[999.5, 111.5]")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonArray([
          JsonNumber(None, Some(999.5), Some("999.5")),
          JsonNumber(None, Some(111.5), Some("111.5")),
        ]),
      )
    }),
    it("Array with Multiple JsonValues", fn() {
      simplejson.parse("[999, \"111\", {}]")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonArray([
          JsonNumber(Some(999), None, Some("999")),
          JsonString("111"),
          JsonObject(dict.from_list([])),
        ]),
      )
    }),
    it("Array inside Object", fn() {
      simplejson.parse("{\"a\": []}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(dict.from_list([#("a", JsonArray([]))])))
    }),
  ])
}

pub fn parse_array_error_tests() {
  describe("Array Parsing - Errors", [
    it("Unclosed Array", fn() {
      simplejson.parse("[")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Unclosed Array with Space", fn() {
      simplejson.parse("[\n\n\r\t ")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid item in Array", fn() {
      simplejson.parse("[\"]")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid item in Array", fn() {
      simplejson.parse("[-]")
      |> expect.to_be_error
      |> expect.to_equal(InvalidNumber("-]", "-]", 1))
    }),
    it("Invalid closing of Array", fn() {
      simplejson.parse("[{\"a\":1]}")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedCharacter("]", "]}", 7))
    }),
  ])
}

pub fn parse_object_tests() {
  describe("Object Parsing - Successful", [
    it("Empty Object", fn() {
      simplejson.parse("{}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(dict.from_list([])))
    }),
    it("Empty Object with Spaces", fn() {
      simplejson.parse("{\n}\t ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(dict.from_list([])))
    }),
    it("Object with Boolean value", fn() {
      simplejson.parse("{\"test\":true}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(dict.from_list([#("test", JsonBool(True))])),
      )
    }),
    it("Object with String value", fn() {
      simplejson.parse("{\"test\":\"true\"}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(dict.from_list([#("test", JsonString("true"))])),
      )
    }),
    it("Object with Null value", fn() {
      simplejson.parse("{\"test\":  null}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(dict.from_list([#("test", JsonNull)])))
    }),
    it("Object with Number value", fn() {
      simplejson.parse("{\"test\":999}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(
          dict.from_list([#("test", JsonNumber(Some(999), None, Some("999")))]),
        ),
      )
    }),
    it("Object with Object value", fn() {
      simplejson.parse("{\"test\":{}}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(dict.from_list([#("test", JsonObject(dict.from_list([])))])),
      )
    }),
    it("Object with Multiple values", fn() {
      simplejson.parse("{\"1\":true, \"2\":false}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(
          dict.from_list([#("1", JsonBool(True)), #("2", JsonBool(False))]),
        ),
      )
    }),
    it("Object with Multiple values and duplicate", fn() {
      simplejson.parse("{\"1\":true, \"2\":false, \"1\":123}")
      |> expect.to_be_ok
      |> expect.to_equal(
        JsonObject(
          dict.from_list([
            #("1", JsonNumber(Some(123), None, Some("123"))),
            #("2", JsonBool(False)),
          ]),
        ),
      )
    }),
  ])
}

pub fn parse_object_error_tests() {
  describe("Object Parsing - Errors", [
    it("Unclosed Object", fn() {
      simplejson.parse("{")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Unclosed Key", fn() {
      simplejson.parse("{\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Just Key", fn() {
      simplejson.parse("{\"key\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Just Key and Colon", fn() {
      simplejson.parse("{\"key\": }")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedCharacter("}", "}", 8))
    }),
  ])
}

pub fn parse_string_tests() {
  describe("String Parsing - Successful", [
    it("Empty String", fn() {
      simplejson.parse("\"\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(""))
    }),
    it("Simple String", fn() {
      simplejson.parse("\"abc\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("abc"))
    }),
    it("String with Escaped Chars", fn() {
      simplejson.parse("\"a\\r\\nb\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("a\r\nb"))
    }),
    it("String with Unicode Chars", fn() {
      simplejson.parse("\"\\u1000\\u2000\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("\u{1000}\u{2000}"))
    }),
    it("String with Quotes and Backslash", fn() {
      simplejson.parse("\"a\\\"\\\\b\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("a\"\\b"))
    }),
  ])
}

pub fn parse_string_error_tests() {
  describe("String Parsing - Errors", [
    it("Unclosed String", fn() {
      simplejson.parse("\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid Char", fn() {
      simplejson.parse("\"\u{05}\"")
      |> expect.to_be_error
      |> expect.to_equal(InvalidCharacter("\u{05}", "\u{05}\"", 1))
    }),
    it("Invalid Escape", fn() {
      simplejson.parse("\"\\h\"")
      |> expect.to_be_error
      |> expect.to_equal(InvalidEscapeCharacter("h", "\\h\"", 1))
    }),
  ])
}
