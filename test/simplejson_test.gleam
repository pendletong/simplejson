import file_streams/file_stream
@target(erlang)
import file_streams/text_encoding
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}
@target(erlang)
import gleam/result
import gleam/string
import simplejson
import simplejson/jsonvalue.{
  InvalidCharacter, InvalidNumber, JsonArray, JsonBool, JsonNull, JsonNumber,
  JsonObject, JsonString, UnexpectedCharacter, UnexpectedEnd,
}
import simplifile
import startest.{describe, it}
import startest/expect

// The below tests all fail with the linked errors
// Most of the errors are due to Erlang deeming
// D800-DFFF as invalid
// There are a couple of BOM entries in there in which 
// BOMs (or the Zero-Width No-Break Space) are not actually
// valid whitespace characters in JSON. However these (FFEF and FFFE) should
// arguably just be ignored as they are not actually part of the
// contents on the string, rather just markers as to how the string
// should have been read
const failing_tests = [
  #(
    "./test/testfiles/y_string_last_surrogates_1_and_2.json",
    Error(InvalidCharacter("DBFF", "DBFF\\uDFFF\"]", 4)),
  ),
  #(
    "./test/testfiles/y_string_accepted_surrogate_pair.json",
    Error(InvalidCharacter("D801", "D801\\udc37\"]", 4)),
  ),
  #(
    "./test/testfiles/y_string_unicode_U+1FFFE_nonchar.json",
    Error(InvalidCharacter("D83F", "D83F\\uDFFE\"]", 4)),
  ),
  #(
    "./test/testfiles/y_string_unicode_U+10FFFE_nonchar.json",
    Error(InvalidCharacter("DBFF", "DBFF\\uDFFE\"]", 4)),
  ),
  #(
    "./test/testfiles/y_string_accepted_surrogate_pairs.json",
    Error(InvalidCharacter("d83d", "d83d\\ude39\\ud83d\\udc8d\"]", 4)),
  ),
  #(
    "./test/testfiles/y_string_surrogates_U+1D11E_MUSICAL_SYMBOL_G_CLEF.json",
    Error(InvalidCharacter("D834", "D834\\uDd1e\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_incomplete_surrogates_escape_valid.json",
    Error(InvalidCharacter("D800", "D800\\uD800\\n\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_UTF-16LE_with_BOM.json",
    Error(UnexpectedCharacter("\u{FEFF}", "\u{FEFF}[\"é\"]", 0)),
  ),
  #(
    "./test/testfiles/i_string_invalid_surrogate.json",
    Error(InvalidCharacter("d800", "d800abc\"]", 4)),
  ),
  #(
    "./test/testfiles/i_object_key_lone_2nd_surrogate.json",
    Error(InvalidCharacter("DFAA", "DFAA\":0}", 4)),
  ),
  #(
    "./test/testfiles/i_string_1st_surrogate_but_2nd_missing.json",
    Error(InvalidCharacter("DADA", "DADA\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_invalid_lonely_surrogate.json",
    Error(InvalidCharacter("d800", "d800\"]", 4)),
  ),
  #(
    "./test/testfiles/i_structure_UTF-8_BOM_empty_object.json",
    Error(UnexpectedCharacter("\u{FEFF}", "\u{FEFF}{}", 0)),
  ),
  #(
    "./test/testfiles/i_string_incomplete_surrogate_pair.json",
    Error(InvalidCharacter("Dd1e", "Dd1ea\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_incomplete_surrogate_and_escape_valid.json",
    Error(InvalidCharacter("D800", "D800\\n\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_lone_second_surrogate.json",
    Error(InvalidCharacter("DFAA", "DFAA\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_1st_valid_surrogate_2nd_invalid.json",
    Error(InvalidCharacter("D888", "D888\\u1234\"]", 4)),
  ),
  #(
    "./test/testfiles/i_string_inverted_surrogates_U+1D11E.json",
    Error(InvalidCharacter("Dd1e", "Dd1e\\uD834\"]", 4)),
  ),
  #(
    "./test/testfiles/i_number_huge_exp.json",
    Error(
      InvalidNumber(
        "0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006",
        "0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
        1,
      ),
    ),
  ),
]

pub fn main() {
  startest.run(startest.default_config())
}

// gleeunit test functions end in `_test`
pub fn simplejson_tests() {
  io.debug("Running tests")
  simplifile.get_files("./test/testfiles")
  |> expect.to_be_ok
  // |> list.filter(fn(name) { string.contains(name, "n_array_invalid_utf8.json") })
  |> list.map(fn(name) {
    it(name, fn() {
      let json = read_file(name) |> expect.to_be_ok
      let parsed = simplejson.parse(json)
      case list.last(string.split(name, "/")) {
        Ok("n" <> _) -> {
          parsed |> result.map_error(fn(_) { Nil }) |> expect.to_be_error
        }
        Ok("i" <> _) | Ok("y" <> _) -> {
          case list.find(failing_tests, fn(e) { e.0 == name }) {
            Ok(#(_, err)) -> {
              parsed |> expect.to_equal(err)
              Nil
            }
            Error(_) -> {
              parsed |> expect.to_be_ok
              Nil
            }
          }
        }
        _ -> {
          Nil
        }
      }
    })
  })
  |> describe("Parse testfiles", _)
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

@target(javascript)
fn read_file(name: String) -> Result(String, Nil) {
  case simplifile.read(name) {
    Ok(content) -> Ok(content)
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
fn read_file(name: String) -> Result(String, Nil) {
  let encoding = case
    string.contains(string.lowercase(name), "utf16")
    || string.contains(string.lowercase(name), "utf-16")
  {
    True -> {
      text_encoding.Utf16(case string.contains(string.lowercase(name), "be") {
        True -> text_encoding.Big
        False -> text_encoding.Little
      })
    }
    False -> {
      text_encoding.Unicode
    }
  }
  let assert Ok(stream) = file_stream.open_read_text(name, encoding)
  let assert Ok(info) = simplifile.file_info(name)
  let json = file_stream.read_chars(stream, info.size)
  let ret = case json {
    Ok(json) -> {
      Ok(json)
    }
    Error(_) -> {
      case simplifile.read(name) {
        Ok(content) -> Ok(content)
        Error(_) -> Error(Nil)
      }
    }
  }
  let assert Ok(Nil) = file_stream.close(stream)

  ret
}
