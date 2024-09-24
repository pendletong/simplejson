import file_streams/file_stream
@target(erlang)
import file_streams/text_encoding
import gleam/io
import gleam/list
@target(erlang)
import gleam/result
import gleam/string
import simplejson
import simplejson/jsonvalue.{InvalidCharacter}
import simplifile
import startest.{describe, it}
import startest/expect

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
        Ok("i" <> _) -> {
          // parsed |> expect.to_be_ok
          Nil
        }
        Ok("y" <> _) -> {
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
