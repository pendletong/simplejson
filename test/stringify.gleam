import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import simplejson/internal/stringify
import simplejson/jsonvalue.{
  JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject, JsonString,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn simple_stringify_tests() {
  describe("Basic Stringify", [
    it("null", fn() { stringify.to_string(JsonNull) |> expect.to_equal("null") }),
    it("boolean", fn() {
      stringify.to_string(JsonBool(True)) |> expect.to_equal("true")
      stringify.to_string(JsonBool(False)) |> expect.to_equal("false")
    }),
    it("number", fn() {
      stringify.to_string(JsonNumber(Some(1), None, Some("1")))
      |> expect.to_equal("1")
      stringify.to_string(JsonNumber(Some(9_090_981), None, Some("9090981")))
      |> expect.to_equal("9090981")
      stringify.to_string(JsonNumber(None, Some(0.1), Some("0.1")))
      |> expect.to_equal("0.1")
      stringify.to_string(JsonNumber(None, Some(0.1234), Some("0.1234")))
      |> expect.to_equal("0.1234")
      stringify.to_string(JsonNumber(None, Some(9876.1234), Some("9876.1234")))
      |> expect.to_equal("9876.1234")
      stringify.to_string(JsonNumber(Some(-1), None, Some("-1")))
      |> expect.to_equal("-1")
      stringify.to_string(JsonNumber(Some(09_090_981), None, Some("-9090981")))
      |> expect.to_equal("-9090981")
      stringify.to_string(JsonNumber(None, Some(-0.1), Some("-0.1")))
      |> expect.to_equal("-0.1")
      stringify.to_string(JsonNumber(None, Some(-0.1234), Some("-0.1234")))
      |> expect.to_equal("-0.1234")
      stringify.to_string(JsonNumber(None, Some(-9876.1234), Some("-9876.1234")))
      |> expect.to_equal("-9876.1234")
      stringify.to_string(JsonNumber(Some(120_000), None, Some("1.2e5")))
      |> expect.to_equal("1.2e5")
      stringify.to_string(JsonNumber(None, Some(0.002), Some("2e-3")))
      |> expect.to_equal("2e-3")
    }),
    it("string", fn() {
      stringify.to_string(JsonString("")) |> expect.to_equal("\"\"")
      stringify.to_string(JsonString("abcde")) |> expect.to_equal("\"abcde\"")
      stringify.to_string(JsonString("\r\n")) |> expect.to_equal("\"\\r\\n\"")
      stringify.to_string(JsonString("\\")) |> expect.to_equal("\"\\\\\"")
      stringify.to_string(JsonString(
        list.range(0, 31)
        |> list.fold("", fn(acc, i) {
          let assert Ok(codepoint) = string.utf_codepoint(i)
          acc <> string.from_utf_codepoints([codepoint])
        }),
      ))
      |> expect.to_equal(
        "\""
        <> list.range(0, 31)
        |> list.fold("", fn(acc, i) {
          acc
          <> case i {
            8 -> "\\b"
            9 -> "\\t"
            10 -> "\\n"
            12 -> "\\f"
            13 -> "\\r"
            _ ->
              "\\u"
              <> string.pad_start(
                string.uppercase(int.to_base16(i)),
                to: 4,
                with: "0",
              )
          }
        })
        <> "\"",
      )
    }),
    it("array", fn() {
      stringify.to_string(JsonArray(dict.new())) |> expect.to_equal("[]")
      stringify.to_string(
        JsonArray(
          dict.from_list([
            #(0, JsonNumber(Some(1), None, None)),
            #(1, JsonNumber(Some(2), None, None)),
            #(2, JsonNumber(Some(3), None, None)),
          ]),
        ),
      )
      |> expect.to_equal("[1,2,3]")
      stringify.to_string(
        JsonArray(
          dict.from_list([
            #(0, JsonNumber(Some(1), None, None)),
            #(1, JsonNumber(None, Some(2.5), None)),
            #(2, JsonNumber(Some(3), None, None)),
          ]),
        ),
      )
      |> expect.to_equal("[1,2.5,3]")
      stringify.to_string(
        JsonArray(
          dict.from_list([
            #(0, JsonNumber(Some(1), None, None)),
            #(1, JsonNumber(Some(2), None, None)),
            #(2, JsonNumber(None, Some(20_000.5), Some("2.00005e4"))),
          ]),
        ),
      )
      |> expect.to_equal("[1,2,2.00005e4]")
      stringify.to_string(
        JsonArray(
          dict.from_list([
            #(
              0,
              JsonArray(
                dict.from_list([
                  #(0, JsonArray(dict.from_list([#(0, JsonArray(dict.new()))]))),
                ]),
              ),
            ),
          ]),
        ),
      )
      |> expect.to_equal("[[[[]]]]")
    }),
    it("object", fn() {
      stringify.to_string(JsonObject(dict.new())) |> expect.to_equal("{}")
      stringify.to_string(JsonObject(dict.from_list([#("a", JsonString("1"))])))
      |> expect.to_equal("{\"a\":\"1\"}")
      stringify.to_string(
        JsonObject(
          dict.from_list([
            #(
              "a",
              JsonObject(
                dict.from_list([
                  #(
                    "b",
                    JsonObject(dict.from_list([#("c", JsonObject(dict.new()))])),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      )
      |> expect.to_equal("{\"a\":{\"b\":{\"c\":{}}}}")
    }),
  ])
}
