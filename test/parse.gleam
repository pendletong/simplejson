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
      simplejson.parse_with_metadata("0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(0), None, Some(JsonMetaData(0, 1))))
      simplejson.parse_with_metadata("-0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(0), None, Some(JsonMetaData(0, 2))))
    }),
    it("Negative", fn() {
      simplejson.parse_with_metadata("-1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-1), None, Some(JsonMetaData(0, 2))))
      simplejson.parse_with_metadata("-1.5")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-1.5), Some(JsonMetaData(0, 4))))
    }),
    it("Exponent", fn() {
      simplejson.parse_with_metadata("1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some(JsonMetaData(0, 3))))
      simplejson.parse_with_metadata("1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(0.01), Some(JsonMetaData(0, 4))))
      simplejson.parse_with_metadata("1e+2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some(JsonMetaData(0, 4))))
      simplejson.parse_with_metadata("1E2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(100), None, Some(JsonMetaData(0, 3))))
      simplejson.parse_with_metadata("1E-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(0.01), Some(JsonMetaData(0, 4))))
      simplejson.parse_with_metadata("-1e2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-100), None, Some(JsonMetaData(0, 4))))
      simplejson.parse_with_metadata("-1e-2")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-0.01), Some(JsonMetaData(0, 5))))
      simplejson.parse("-9.09e1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(None, Some(-90.9), Some(JsonMetaData(0, 7))))
    }),
    it("Float", fn() {
      simplejson.parse_with_metadata("0.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        None,
        Some(0.1234),
        Some(JsonMetaData(0, 6)),
      ))
      simplejson.parse_with_metadata("-9876.1234")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        None,
        Some(-9876.1234),
        Some(JsonMetaData(0, 10)),
      ))
    }),
    it("Truncate", fn() {
      simplejson.parse_with_metadata("0.0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(0), None, Some(JsonMetaData(0, 3))))
      simplejson.parse_with_metadata("99.0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(99), None, Some(JsonMetaData(0, 4))))
      simplejson.parse_with_metadata("-99.0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-99), None, Some(JsonMetaData(0, 5))))
      simplejson.parse_with_metadata("9.9e1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(99), None, Some(JsonMetaData(0, 5))))
      simplejson.parse_with_metadata("-9.9e1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(Some(-99), None, Some(JsonMetaData(0, 7))))
    }),
  ])
}

pub fn parse_array_tests() {
  describe("Array Parsing - Successful", [
    it("Empty Array", fn() {
      simplejson.parse_with_metadata("[]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(dict.new(), Some(JsonMetaData(0, 2))))
    }),
    it("Array with String", fn() {
      simplejson.parse_with_metadata("[\"a\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([#(0, JsonString("a", Some(JsonMetaData(1, 4))))]),
        Some(JsonMetaData(0, 5)),
      ))
    }),
    it("Array with Multiple Strings", fn() {
      simplejson.parse_with_metadata("[\"a\", \"z\"]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonString("a", Some(JsonMetaData(1, 4)))),
          #(1, JsonString("z", Some(JsonMetaData(6, 9)))),
        ]),
        Some(JsonMetaData(0, 10)),
      ))
    }),
    it("Array with String and Spaces", fn() {
      simplejson.parse_with_metadata(" [ \"a\" ] ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([#(0, JsonString("a", Some(JsonMetaData(3, 6))))]),
        Some(JsonMetaData(1, 8)),
      ))
    }),
    it("Array with Int", fn() {
      simplejson.parse_with_metadata("[123]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonNumber(Some(123), None, Some(JsonMetaData(1, 4)))),
        ]),
        Some(JsonMetaData(0, 5)),
      ))
    }),
    it("Array with Multiple Ints", fn() {
      simplejson.parse_with_metadata("[999, 111]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonNumber(Some(999), None, Some(JsonMetaData(1, 4)))),
          #(1, JsonNumber(Some(111), None, Some(JsonMetaData(6, 9)))),
        ]),
        Some(JsonMetaData(0, 10)),
      ))
    }),
    it("Array with Float", fn() {
      simplejson.parse_with_metadata("[123.5]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonNumber(None, Some(123.5), Some(JsonMetaData(1, 6)))),
        ]),
        Some(JsonMetaData(0, 7)),
      ))
    }),
    it("Array with Multiple Floats", fn() {
      simplejson.parse_with_metadata("[999.5, 111.5]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonNumber(None, Some(999.5), Some(JsonMetaData(1, 6)))),
          #(1, JsonNumber(None, Some(111.5), Some(JsonMetaData(8, 13)))),
        ]),
        Some(JsonMetaData(0, 14)),
      ))
    }),
    it("Array with Multiple JsonValues", fn() {
      simplejson.parse_with_metadata("[999, \"111\", {}]")
      |> expect.to_be_ok
      |> expect.to_equal(JsonArray(
        dict.from_list([
          #(0, JsonNumber(Some(999), None, Some(JsonMetaData(1, 4)))),
          #(1, JsonString("111", Some(JsonMetaData(6, 11)))),
          #(2, JsonObject(dict.from_list([]), Some(JsonMetaData(13, 15)))),
        ]),
        Some(JsonMetaData(0, 16)),
      ))
    }),
    it("Array inside Object", fn() {
      simplejson.parse_with_metadata("{\"a\": []}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([#("a", JsonArray(dict.new(), Some(JsonMetaData(6, 8))))]),
        Some(JsonMetaData(0, 9)),
      ))
    }),
  ])
}

pub fn parse_array_error_tests() {
  describe("Array Parsing - Errors", [
    it("Unclosed Array", fn() {
      simplejson.parse_with_metadata("[")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Unclosed Array with Space", fn() {
      simplejson.parse_with_metadata("[\n\n\r\t ")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid item in Array", fn() {
      simplejson.parse_with_metadata("[\"]")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid item in Array", fn() {
      simplejson.parse_with_metadata("[-]")
      |> expect.to_be_error
      |> expect.to_equal(InvalidNumber("-]", "[-]", 1))
    }),
    it("Invalid closing of Array", fn() {
      simplejson.parse_with_metadata("[{\"a\":1]}")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedCharacter("]", "\"a\":1]}", 7))
    }),
  ])
}

pub fn parse_object_tests() {
  describe("Object Parsing - Successful", [
    it("Empty Object", fn() {
      simplejson.parse_with_metadata("{}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([]),
        Some(JsonMetaData(0, 2)),
      ))
    }),
    it("Empty Object with Spaces", fn() {
      simplejson.parse_with_metadata("{\n}\t ")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([]),
        Some(JsonMetaData(0, 3)),
      ))
    }),
    it("Object with Boolean value", fn() {
      simplejson.parse_with_metadata("{\"test\":true}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([#("test", JsonBool(True, Some(JsonMetaData(8, 12))))]),
        Some(JsonMetaData(0, 13)),
      ))
    }),
    it("Object with String value", fn() {
      simplejson.parse_with_metadata("{\"test\":\"true\"}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([
          #("test", JsonString("true", Some(JsonMetaData(8, 14)))),
        ]),
        Some(JsonMetaData(0, 15)),
      ))
    }),
    it("Object with Null value", fn() {
      simplejson.parse_with_metadata("{\"test\":  null}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([#("test", JsonNull(Some(JsonMetaData(10, 14))))]),
        Some(JsonMetaData(0, 15)),
      ))
    }),
    it("Object with Number value", fn() {
      simplejson.parse_with_metadata("{\"test\":999}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([
          #("test", JsonNumber(Some(999), None, Some(JsonMetaData(8, 11)))),
        ]),
        Some(JsonMetaData(0, 12)),
      ))
    }),
    it("Object with Object value", fn() {
      simplejson.parse_with_metadata("{\"test\":{}}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([
          #("test", JsonObject(dict.from_list([]), Some(JsonMetaData(8, 10)))),
        ]),
        Some(JsonMetaData(0, 11)),
      ))
    }),
    it("Object with Multiple values", fn() {
      simplejson.parse_with_metadata("{\"1\":true, \"2\":false}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([
          #("1", JsonBool(True, Some(JsonMetaData(5, 9)))),
          #("2", JsonBool(False, Some(JsonMetaData(15, 20)))),
        ]),
        Some(JsonMetaData(0, 21)),
      ))
    }),
    it("Object with Multiple values and duplicate", fn() {
      simplejson.parse_with_metadata("{\"1\":true, \"2\":false, \"1\":123}")
      |> expect.to_be_ok
      |> expect.to_equal(JsonObject(
        dict.from_list([
          #("1", JsonNumber(Some(123), None, Some(JsonMetaData(26, 29)))),
          #("2", JsonBool(False, Some(JsonMetaData(15, 20)))),
        ]),
        Some(JsonMetaData(0, 30)),
      ))
    }),
  ])
}

pub fn parse_object_error_tests() {
  describe("Object Parsing - Errors", [
    it("Unclosed Object", fn() {
      simplejson.parse_with_metadata("{")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Unclosed Key", fn() {
      simplejson.parse_with_metadata("{\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Just Key", fn() {
      simplejson.parse_with_metadata("{\"key\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Just Key and Colon", fn() {
      simplejson.parse_with_metadata("{\"key\": }")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedCharacter("}", "ey\": }", 8))
    }),
  ])
}

pub fn parse_string_tests() {
  describe("String Parsing - Successful", [
    it("Empty String", fn() {
      simplejson.parse_with_metadata("\"\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("", Some(JsonMetaData(0, 2))))
    }),
    it("Simple String", fn() {
      simplejson.parse_with_metadata("\"abc\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("abc", Some(JsonMetaData(0, 5))))
    }),
    it("String with Escaped Chars", fn() {
      simplejson.parse_with_metadata("\"a\\r\\nb\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("a\r\nb", Some(JsonMetaData(0, 8))))
    }),
    it("String with Unicode Chars", fn() {
      simplejson.parse_with_metadata("\"\\u1000\\u2000\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString(
        "\u{1000}\u{2000}",
        Some(JsonMetaData(0, 14)),
      ))
    }),
    it("String with Quotes and Backslash", fn() {
      simplejson.parse_with_metadata("\"a\\\"\\\\b\"")
      |> expect.to_be_ok
      |> expect.to_equal(JsonString("a\"\\b", Some(JsonMetaData(0, 8))))
    }),
  ])
}

pub fn parse_string_error_tests() {
  describe("String Parsing - Errors", [
    it("Unclosed String", fn() {
      simplejson.parse_with_metadata("\"")
      |> expect.to_be_error
      |> expect.to_equal(UnexpectedEnd)
    }),
    it("Invalid Char", fn() {
      simplejson.parse_with_metadata("\"\u{05}\"")
      |> expect.to_be_error
      |> expect.to_equal(InvalidCharacter("\u{05}", "\"\u{05}\"", 1))
    }),
    it("Invalid Escape", fn() {
      simplejson.parse_with_metadata("\"\\h\"")
      |> expect.to_be_error
      |> expect.to_equal(InvalidEscapeCharacter("h", "\"\\h\"", 1))
    }),
  ])
}
