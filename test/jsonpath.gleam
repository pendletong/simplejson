import gleam/bool
import gleam/dict
import gleam/list
import gleam/string
import simplejson
import simplejson/internal/jsonpath
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject, JsonString}
import simplifile
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn jsonpath_tests() {
  test_folder("./jsonpath-compliance-test-suite/tests")
}

pub fn whitespace_tests() {
  test_folder("./jsonpath-compliance-test-suite/tests/whitespace")
}

pub fn test_folder(folder: String) {
  simplifile.get_files(folder)
  |> expect.to_be_ok
  |> list.filter(fn(name) {
    // Ignore tests we can't possibly pass yet
    !string.contains(name, "filter")
    && !string.contains(name, "operators")
    && !string.contains(name, "functions")
  })
  |> list.map(fn(name) {
    let assert Ok(json) = read_file(name)
    let parsed = simplejson.parse(json)

    describe(name, parsed |> expect.to_be_ok |> run_tests_in_json)
  })
  |> describe("Parse testfiles", _)
}

fn run_tests_in_json(json: JsonValue) {
  case json {
    JsonObject(d) -> {
      case dict.get(d, "tests") {
        Ok(JsonArray(a)) -> {
          list.range(0, dict.size(a) - 1)
          |> list.map(fn(i) {
            let assert Ok(JsonObject(t)) = dict.get(a, i)
            case dict.get(t, "name") {
              Ok(JsonString(n)) -> {
                it(n, fn() { run_test_in_json(t) })
              }
              _ -> panic
            }
          })
        }
        _ -> panic
      }
    }
    _ -> panic
  }
}

fn run_test_in_json(t) {
  let assert Ok(JsonString(selector)) = dict.get(t, "selector")

  case dict.get(t, "invalid_selector") {
    Ok(jsonvalue.JsonBool(True)) -> {
      jsonpath.parse_path(selector) |> expect.to_be_error
      Nil
    }
    _ -> {
      jsonpath.parse_path(selector) |> expect.to_be_ok
      Nil
    }
  }
}

pub fn read_file(name: String) -> Result(String, Nil) {
  case simplifile.read(name) {
    Ok(content) -> Ok(content)
    Error(_) -> Error(Nil)
  }
}
