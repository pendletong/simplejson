import gleam/dict
import gleam/option.{None, Some}
import simplejson
import simplejson/jsonvalue.{
  InvalidCharacter, InvalidEscapeCharacter, InvalidNumber, JsonArray, JsonBool,
  JsonMetaData, JsonNull, JsonNumber, JsonObject, JsonString,
  UnexpectedCharacter, UnexpectedEnd,
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
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 1),
        Some(0),
        None,
        Some("0"),
      ))
      simplejson.parse("-0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 2),
        Some(0),
        None,
        Some("-0"),
      ))
    }),
    it("Negative", fn() {
      simplejson.parse("-1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 2),
        Some(-1),
        None,
        Some("-1"),
      ))
      simplejson.parse("-1.5")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 4),
        None,
        Some(-1.5),
        Some("-1.5"),
      ))
    }),
    it("Exponent", fn() {
      simplejson.parse("1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 3),
        Some(100),
        None,
        Some("1e2"),
      ))
      simplejson.parse("1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 4),
        None,
        Some(0.01),
        Some("1e-2"),
      ))
      simplejson.parse("1e+2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 4),
        Some(100),
        None,
        Some("1e2"),
      ))
      simplejson.parse("1E2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 3),
        Some(100),
        None,
        Some("1e2"),
      ))
      simplejson.parse("1E-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 4),
        None,
        Some(0.01),
        Some("1e-2"),
      ))
      simplejson.parse("-1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 4),
        Some(-100),
        None,
        Some("-1e2"),
      ))
      simplejson.parse("-1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 5),
        None,
        Some(-0.01),
        Some("-1e-2"),
      ))
    }),
    it("Float", fn() {
      simplejson.parse("0.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 6),
        None,
        Some(0.1234),
        Some("0.1234"),
      ))
      simplejson.parse("-9876.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(0, 10),
        None,
        Some(-9876.1234),
        Some("-9876.1234"),
      ))
    }),
  ])
}

pub fn parse_array_tests() {
  describe("Array Parsing - Successful", [
    it("Empty Array", fn() {
      simplejson.parse("[]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(JsonMetaData(0, 2), dict.new()))
    }),
    it("Array with String", fn() {
      simplejson.parse("[\"a\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 5),
        dict.from_list([#(0, JsonString(JsonMetaData(1, 4), "a"))]),
      ))
    }),
    it("Array with Multiple Strings", fn() {
      simplejson.parse("[\"a\", \"z\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 10),
        dict.from_list([
          #(0, JsonString(JsonMetaData(1, 4), "a")),
          #(1, JsonString(JsonMetaData(6, 9), "z")),
        ]),
      ))
    }),
    it("Array with String and Spaces", fn() {
      simplejson.parse(" [ \"a\" ] ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(1, 8),
        dict.from_list([#(0, JsonString(JsonMetaData(3, 6), "a"))]),
      ))
    }),
    it("Array with Int", fn() {
      simplejson.parse("[123]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 5),
        dict.from_list([
          #(0, JsonNumber(JsonMetaData(1, 4), Some(123), None, Some("123"))),
        ]),
      ))
    }),
    it("Array with Multiple Ints", fn() {
      simplejson.parse("[999, 111]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 10),
        dict.from_list([
          #(0, JsonNumber(JsonMetaData(1, 4), Some(999), None, Some("999"))),
          #(1, JsonNumber(JsonMetaData(6, 9), Some(111), None, Some("111"))),
        ]),
      ))
    }),
    it("Array with Float", fn() {
      simplejson.parse("[123.5]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 7),
        dict.from_list([
          #(0, JsonNumber(JsonMetaData(1, 6), None, Some(123.5), Some("123.5"))),
        ]),
      ))
    }),
    it("Array with Multiple Floats", fn() {
      simplejson.parse("[999.5, 111.5]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 14),
        dict.from_list([
          #(0, JsonNumber(JsonMetaData(1, 6), None, Some(999.5), Some("999.5"))),
          #(
            1,
            JsonNumber(JsonMetaData(8, 13), None, Some(111.5), Some("111.5")),
          ),
        ]),
      ))
    }),
    it("Array with Multiple JsonValues", fn() {
      simplejson.parse("[999, \"111\", {}]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        JsonMetaData(0, 16),
        dict.from_list([
          #(0, JsonNumber(JsonMetaData(1, 4), Some(999), None, Some("999"))),
          #(1, JsonString(JsonMetaData(6, 11), "111")),
          #(2, JsonObject(JsonMetaData(13, 15), dict.from_list([]))),
        ]),
      ))
    }),
    it("Array inside Object", fn() {
      simplejson.parse("{\"a\": []}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 9),
        dict.from_list([#("a", JsonArray(JsonMetaData(6, 8), dict.new()))]),
      ))
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
      |> expect.to_equal(InvalidNumber("-]", "[-]", 1))
    }),
    it("Invalid closing of Array", fn() {
      simplejson.parse("[{\"a\":1]}")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedCharacter("]", "\"a\":1]}", 7))
    }),
  ])
}

pub fn parse_object_tests() {
  describe("Object Parsing - Successful", [
    it("Empty Object", fn() {
      simplejson.parse("{}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(JsonMetaData(0, 2), dict.from_list([])))
    }),
    it("Empty Object with Spaces", fn() {
      simplejson.parse("{\n}\t ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(JsonMetaData(0, 3), dict.from_list([])))
    }),
    it("Object with Boolean value", fn() {
      simplejson.parse("{\"test\":true}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 13),
        dict.from_list([#("test", JsonBool(JsonMetaData(8, 12), True))]),
      ))
    }),
    it("Object with String value", fn() {
      simplejson.parse("{\"test\":\"true\"}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 15),
        dict.from_list([#("test", JsonString(JsonMetaData(8, 14), "true"))]),
      ))
    }),
    it("Object with Null value", fn() {
      simplejson.parse("{\"test\":  null}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 15),
        dict.from_list([#("test", JsonNull(JsonMetaData(10, 14)))]),
      ))
    }),
    it("Object with Number value", fn() {
      simplejson.parse("{\"test\":999}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 12),
        dict.from_list([
          #(
            "test",
            JsonNumber(JsonMetaData(8, 11), Some(999), None, Some("999")),
          ),
        ]),
      ))
    }),
    it("Object with Object value", fn() {
      simplejson.parse("{\"test\":{}}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 11),
        dict.from_list([
          #("test", JsonObject(JsonMetaData(8, 10), dict.from_list([]))),
        ]),
      ))
    }),
    it("Object with Multiple values", fn() {
      simplejson.parse("{\"1\":true, \"2\":false}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 21),
        dict.from_list([
          #("1", JsonBool(JsonMetaData(5, 9), True)),
          #("2", JsonBool(JsonMetaData(15, 20), False)),
        ]),
      ))
    }),
    it("Object with Multiple values and duplicate", fn() {
      simplejson.parse("{\"1\":true, \"2\":false, \"1\":123}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        JsonMetaData(0, 30),
        dict.from_list([
          #("1", JsonNumber(JsonMetaData(26, 29), Some(123), None, Some("123"))),
          #("2", JsonBool(JsonMetaData(15, 20), False)),
        ]),
      ))
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
      |> expect.to_equal(UnexpectedCharacter("}", "ey\": }", 8))
    }),
  ])
}

pub fn parse_string_tests() {
  describe("String Parsing - Successful", [
    it("Empty String", fn() {
      simplejson.parse("\"\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(JsonMetaData(0, 2), ""))
    }),
    it("Simple String", fn() {
      simplejson.parse("\"abc\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(JsonMetaData(0, 5), "abc"))
    }),
    it("String with Escaped Chars", fn() {
      simplejson.parse("\"a\\r\\nb\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(JsonMetaData(0, 8), "a\r\nb"))
    }),
    it("String with Unicode Chars", fn() {
      simplejson.parse("\"\\u1000\\u2000\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(JsonMetaData(0, 14), "\u{1000}\u{2000}"))
    }),
    it("String with Quotes and Backslash", fn() {
      simplejson.parse("\"a\\\"\\\\b\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(JsonMetaData(0, 8), "a\"\\b"))
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
      |> expect.to_equal(InvalidCharacter("\u{05}", "\"\u{05}\"", 1))
    }),
    it("Invalid Escape", fn() {
      simplejson.parse("\"\\h\"")
      |> expect.to_be_error
      |> expect.to_equal(InvalidEscapeCharacter("h", "\"\\h\"", 1))
    }),
  ])
}
