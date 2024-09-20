import gleam/io
import gleam/list
import gleam/string
import simplejson
import simplifile
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

// gleeunit test functions end in `_test`
pub fn simplejson_tests() {
  io.debug("Running tests")
  simplifile.get_files("./test/testfiles")
  |> expect.to_be_ok
  // |> list.filter(fn(name) {
  //   string.contains(name, "n_structure_incomplete_UTF8_BOM.json")
  // })
  |> list.map(fn(name) {
    it(name, fn() {
      let json =
        simplifile.read(name)
        |> expect.to_be_ok
      let parsed = simplejson.parse(json)
      case list.last(string.split(name, "/")) {
        Ok("n" <> _) -> {
          parsed |> expect.to_be_error
        }
        Ok("i" <> _) -> {
          parsed |> expect.to_be_ok
          Nil
        }
        Ok("y" <> _) -> {
          parsed |> expect.to_be_ok
          Nil
        }
        _ -> {
          Nil
        }
      }
    })
  })
  |> describe("Parse testfiles", _)
}
