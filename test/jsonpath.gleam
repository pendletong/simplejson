import bigdecimal
import gleam/dict
import gleam/list
import simplejson
import simplejson/internal/jsonpath
import simplejson/internal/query
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString, NoMD,
}
import simplifile
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn general_parse_tests() {
  describe("General JsonPath parsing", [
    it("parse number with leading zeros in fraction", fn() {
      let assert Ok(bd) = bigdecimal.from_string("3.00005")
      jsonpath.parse_path("$[?$.a==3.00005]")
      |> expect.to_be_ok
      |> expect.to_equal([
        jsonpath.Child([
          jsonpath.Filter(
            jsonpath.LogicalExpression(
              jsonpath.LogicalOrExpression([
                jsonpath.LogicalAndExpression([
                  jsonpath.Comparison(
                    jsonpath.QueryCmp(
                      jsonpath.AbsQuery([jsonpath.SingleName("a")]),
                    ),
                    jsonpath.Literal(jsonpath.Number(bd)),
                    jsonpath.Eq,
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ])
    }),
  ])
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
  |> list.map(fn(name) {
    let assert Ok(json) = read_file(name)
    let parsed = simplejson.parse(json)

    describe(name, parsed |> expect.to_be_ok |> run_tests_in_json)
  })
  |> describe("JsonPath RFC9535 Tests", _)
}

fn run_tests_in_json(json: JsonValue) {
  case json {
    JsonObject(_, d) -> {
      case dict.get(d, "tests") {
        Ok(JsonArray(_, a)) -> {
          list.range(0, dict.size(a) - 1)
          |> list.map(fn(i) {
            let assert Ok(jv) = dict.get(a, i)
            let assert JsonObject(_, t) = jv
            case dict.get(t, "name") {
              Ok(JsonString(_, n)) -> {
                it(n, fn() { run_test_in_json(jv) })
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

fn run_test_in_json(jv: JsonValue) {
  let assert JsonObject(_, t) = jv |> clear_metadata
  let assert Ok(JsonString(_, selector)) = dict.get(t, "selector")

  case dict.get(t, "invalid_selector") {
    Ok(JsonBool(_, True)) -> {
      jsonpath.parse_path(selector) |> expect.to_be_error
      Nil
    }
    _ -> {
      let assert Ok(testjson) = dict.get(t, "document")
      let jsonpath =
        jsonpath.parse_path(selector)
        |> expect.to_be_ok
      let ours = query.query(testjson, jsonpath, testjson) |> clear_metadata
      case dict.get(t, "result") {
        Ok(result) -> {
          ours
          |> expect.to_equal(result)
        }
        Error(_) -> {
          case dict.get(t, "results") {
            Ok(JsonArray(_, d)) -> {
              expect.list_to_contain(dict.values(d), ours)
            }
            _ -> panic
          }
        }
      }
      Nil
    }
  }
}

fn clear_metadata(json: JsonValue) -> JsonValue {
  case json {
    JsonArray(_, array:) -> {
      JsonArray(NoMD, dict.map_values(array, fn(k, v) { clear_metadata(v) }))
    }
    JsonObject(_, object:) -> {
      JsonObject(NoMD, dict.map_values(object, fn(k, v) { clear_metadata(v) }))
    }
    JsonString(_, str:) -> JsonString(NoMD, str)
    JsonBool(_, bool:) -> JsonBool(NoMD, bool)
    JsonNull(_) -> JsonNull(NoMD)
    JsonNumber(_, int:, float:, original:) ->
      JsonNumber(NoMD, int, float, original)
  }
}

pub fn read_file(name: String) -> Result(String, Nil) {
  case simplifile.read(name) {
    Ok(content) -> Ok(content)
    Error(_) -> Error(Nil)
  }
}
