@target(erlang)
import file_streams/file_stream
@target(erlang)
import file_streams/text_encoding

import gleam/bool
import gleam/list
import gleam/result
import gleam/string
import simplejson
import simplejson/jsonvalue.{
  type ParseError, InvalidHex, InvalidNumber, UnexpectedCharacter,
}
import simplifile
import startest.{describe, it}
import startest/expect

type Test {
  Test(
    file: String,
    erlang_error: Result(String, ParseError),
    javascript_error: Result(String, ParseError),
  )
}

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
  Test(
    "./JSONTestSuite/test_parsing/y_string_last_surrogates_1_and_2.json",
    Error(InvalidHex("DBFF", "[\"\\uDBFF\\", 4)),
    Error(InvalidHex("DBFF", "[\"\\uDBFF\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/y_string_accepted_surrogate_pair.json",
    Error(InvalidHex("D801", "[\"\\uD801\\", 4)),
    Error(InvalidHex("D801", "[\"\\uD801\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/y_string_unicode_U+1FFFE_nonchar.json",
    Error(InvalidHex("D83F", "[\"\\uD83F\\", 4)),
    Error(InvalidHex("D83F", "[\"\\uD83F\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/y_string_unicode_U+10FFFE_nonchar.json",
    Error(InvalidHex("DBFF", "[\"\\uDBFF\\", 4)),
    Error(InvalidHex("DBFF", "[\"\\uDBFF\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/y_string_accepted_surrogate_pairs.json",
    Error(InvalidHex("d83d", "[\"\\ud83d\\", 4)),
    Error(InvalidHex("d83d", "[\"\\ud83d\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/y_string_surrogates_U+1D11E_MUSICAL_SYMBOL_G_CLEF.json",
    Error(InvalidHex("D834", "[\"\\uD834\\", 4)),
    Error(InvalidHex("D834", "[\"\\uD834\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_incomplete_surrogates_escape_valid.json",
    Error(InvalidHex("D800", "[\"\\uD800\\", 4)),
    Error(InvalidHex("D800", "[\"\\uD800\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_UTF-16LE_with_BOM.json",
    Error(UnexpectedCharacter("\u{FEFF}", "\u{FEFF}[\"é\"", 0)),
    Error(UnexpectedCharacter("\u{FEFF}", "\u{FEFF}[\"é\"", 0)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_invalid_surrogate.json",
    Error(InvalidHex("d800", "[\"\\ud800a", 4)),
    Error(InvalidHex("d800", "[\"\\ud800a", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_object_key_lone_2nd_surrogate.json",
    Error(InvalidHex("DFAA", "{\"\\uDFAA\"", 4)),
    Error(InvalidHex("DFAA", "{\"\\uDFAA\"", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_1st_surrogate_but_2nd_missing.json",
    Error(InvalidHex("DADA", "[\"\\uDADA\"", 4)),
    Error(InvalidHex("DADA", "[\"\\uDADA\"", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_invalid_lonely_surrogate.json",
    Error(InvalidHex("d800", "[\"\\ud800\"", 4)),
    Error(InvalidHex("d800", "[\"\\ud800\"", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_structure_UTF-8_BOM_empty_object.json",
    Error(UnexpectedCharacter("\u{FEFF}", "\u{FEFF}{}", 0)),
    Ok("{}"),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_incomplete_surrogate_pair.json",
    Error(InvalidHex("Dd1e", "[\"\\uDd1ea", 4)),
    Error(InvalidHex("Dd1e", "[\"\\uDd1ea", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_incomplete_surrogate_and_escape_valid.json",
    Error(InvalidHex("D800", "[\"\\uD800\\", 4)),
    Error(InvalidHex("D800", "[\"\\uD800\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_lone_second_surrogate.json",
    Error(InvalidHex("DFAA", "[\"\\uDFAA\"", 4)),
    Error(InvalidHex("DFAA", "[\"\\uDFAA\"", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_1st_valid_surrogate_2nd_invalid.json",
    Error(InvalidHex("D888", "[\"\\uD888\\", 4)),
    Error(InvalidHex("D888", "[\"\\uD888\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_string_inverted_surrogates_U+1D11E.json",
    Error(InvalidHex("Dd1e", "[\"\\uDd1e\\", 4)),
    Error(InvalidHex("Dd1e", "[\"\\uDd1e\\", 4)),
  ),
  Test(
    "./JSONTestSuite/test_parsing/i_number_huge_exp.json",
    Error(
      InvalidNumber(
        "0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006",
        "[0.4e0",
        1,
      ),
    ),
    Error(
      InvalidNumber(
        "0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006",
        "[0.4e0",
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
  simplifile.get_files("./JSONTestSuite/test_parsing")
  |> expect.to_be_ok
  // |> list.filter(fn(name) { string.contains(name, "n_array_invalid_utf8.json") })
  |> list.map(fn(name) {
    it(name, fn() {
      let json = read_file(name)
      use <- bool.guard(when: json == Error(Nil), return: Nil)
      let assert Ok(json) = json
      let parsed = simplejson.parse(json)
      case list.last(string.split(name, "/")) {
        Ok("n" <> _) -> {
          parsed |> result.map_error(fn(_) { Nil }) |> expect.to_be_error
        }
        Ok("i" <> _) | Ok("y" <> _) -> {
          case list.find(failing_tests, fn(e) { e.file == name }) {
            Ok(Test(_, erlang_err, js_err)) -> {
              let res = case is_javascript {
                True -> js_err

                False -> erlang_err
              }
              let res = case res {
                Error(err) -> Error(err)
                Ok(str) -> simplejson.parse(str)
              }
              parsed |> expect.to_equal(res)
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
  |> describe("Parse JSON from testfiles", _)
}

// We need separate read_file fns for erlang and javascript
// because loading utf-16 encoded files in erlang using simplifile
// seemed to cause some issues
// Maybe this can be removed in the future but for the moment it
// prevents more tests failing than the ones in the failing_tests const above
@target(javascript)
pub fn read_file(name: String) -> Result(String, Nil) {
  case simplifile.read(name) {
    Ok(content) -> Ok(content)
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
pub fn read_file(name: String) -> Result(String, Nil) {
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

@target(erlang)
const is_javascript = False

@target(javascript)
const is_javascript = True
