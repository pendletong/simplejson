import gleam/option.{None, Some}
import simplejson
import simplejson/jsonvalue.{JsonMetaData, JsonNumber, NoMD}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn pointer_tests() {
  describe("Simple JSON Path Test", [
    it("no path", fn() {
      let assert Ok(json) = simplejson.parse("{\"a\":[1,2,{\"b\":123}]}")
      simplejson.jsonpath(json, "") |> expect.to_be_ok |> expect.to_equal(json)
    }),
    it("properties", fn() {
      let assert Ok(json) = simplejson.parse("{\"a\":1}")
      simplejson.jsonpath(json, "a")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(5, 6),
        Some(1),
        None,
        Some("1"),
      ))
    }),

    it("array pos", fn() {
      let assert Ok(json) = simplejson.parse("[1,2,3]")
      simplejson.jsonpath(json, "#1")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(3, 4),
        Some(2),
        None,
        Some("2"),
      ))
      let assert Ok(json) = simplejson.parse("[1,2,3]")
      simplejson.jsonpath(json, "#0")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(1, 2),
        Some(1),
        None,
        Some("1"),
      ))
    }),
    it("properties and array pos", fn() {
      let assert Ok(json) = simplejson.parse("{\"a\":[1,2,{\"b\":123}]}")
      simplejson.jsonpath(json, "a.#2.b")
      |> expect.to_be_ok
      |> expect.to_equal(JsonNumber(
        JsonMetaData(15, 18),
        Some(123),
        None,
        Some("123"),
      ))
    }),
  ])
}

pub fn pointer_error_tests() {
  describe("Simple JSON Path Errors Test", [
    it("non-existent properties", fn() {
      let assert Ok(json) = simplejson.parse("{\"a\":1}")
      simplejson.jsonpath(json, "b")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.PathNotFound)
    }),
    it("array out of bounds", fn() {
      let assert Ok(json) = simplejson.parse("[1,2,3]")
      simplejson.jsonpath(json, "#4")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.PathNotFound)
    }),
    it("incorrect type", fn() {
      let assert Ok(json) = simplejson.parse("\"123\"")
      simplejson.jsonpath(json, "#1")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.PathNotFound)
      let assert Ok(json) = simplejson.parse("\"123\"")
      simplejson.jsonpath(json, "z")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.PathNotFound)
    }),
    it("array out of bounds", fn() {
      let assert Ok(json) = simplejson.parse("[1,2,3]")
      simplejson.jsonpath(json, "#-1")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.PathNotFound)
    }),
    it("invalid path", fn() {
      let assert Ok(json) = simplejson.parse("[1,2,3]")
      simplejson.jsonpath(json, "#b")
      |> expect.to_be_error
      |> expect.to_equal(jsonvalue.InvalidJsonPath)
    }),
  ])
}
