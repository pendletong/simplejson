import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/types.{
  AlwaysFail, IncorrectType, InvalidComparison, MultipleInfo, ValidationError,
}
import simplejson/internal/schema2/validator2
import simplejson/internal/stringify
import simplejson/jsonvalue.{
  JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject, JsonString,
}
import simplifile
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn schema_basic_tests() {
  describe("Basic tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("true") |> expect.to_be_ok
        schema2.get_validator("false") |> expect.to_be_ok
        schema2.get_validator("{}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"number\"}") |> expect.to_be_ok
        Nil
      }),
      it("Invalid Schema", fn() {
        schema2.get_validator("null") |> expect.to_be_error
        schema2.get_validator("123") |> expect.to_be_error
        schema2.get_validator("\"123\"") |> expect.to_be_error
        schema2.get_validator("[]") |> expect.to_be_error
        Nil
      }),
    ]),
    describe("Basic true/false validity", [
      it("True should be valid", fn() {
        let schema = schema2.get_validator("true") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("false")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("False should be invalid", fn() {
        let schema = schema2.get_validator("false") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
        let assert Ok(json) = simplejson.parse("false")
        validator2.validate(json, schema)
        |> expect.to_equal(#(False, Some(AlwaysFail)))
      }),
    ]),
  ])
}

pub fn schema_type_tests() {
  describe("Type tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"type\":\"number\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"integer\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"string\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"null\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"array\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"object\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":\"boolean\"}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":[\"boolean\"]}") |> expect.to_be_ok
        schema2.get_validator("{\"type\":[\"boolean\", \"string\"]}")
        |> expect.to_be_ok
        schema2.get_validator("{\"type\":[]}") |> expect.to_be_ok
        Nil
      }),
      it("Invalid Schema", fn() {
        schema2.get_validator("{\"type\":\"bool\"}") |> expect.to_be_error
        schema2.get_validator("{\"type\":\"nul\"}") |> expect.to_be_error
        schema2.get_validator("{\"type\":[\"bool\"]}") |> expect.to_be_error
        schema2.get_validator("{\"type\":[\"boolean\", \"boolean\"]}")
        |> expect.to_be_error
        Nil
      }),
    ]),
    describe("Basic type validity", [
      it("Null type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"null\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonNumber(Some(1), None, None))),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonArray(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonObject(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonString("null", None))),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonBool(True, None))),
        ))
      }),
      it("String Type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, JsonNumber(Some(1), None, None))),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, JsonArray(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, JsonObject(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, JsonBool(True, None))),
        ))
      }),
      it("Integer Type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"integer\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("2.0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("2.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonNumber(None, Some(2.1), None))),
        ))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonString("null", None))),
        ))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonArray(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonObject(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, JsonBool(True, None))),
        ))
      }),
      it("Number Type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("2.0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("2.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, JsonString("null", None))),
        ))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, JsonArray(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, JsonObject(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, JsonBool(True, None))),
        ))
      }),
      it("Boolean type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"boolean\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("false")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Boolean, JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Boolean, JsonNumber(Some(1), None, None))),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Boolean, JsonArray(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Boolean, JsonObject(dict.new(), None))),
        ))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Boolean, JsonString("null", None))),
        ))
      }),
      it("Array type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"array\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("[1,2,3]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Array(types.AnyType), JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Array(types.AnyType),
            JsonNumber(Some(1), None, None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Array(types.AnyType),
            JsonObject(dict.new(), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Array(types.AnyType),
            JsonString("null", None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Array(types.AnyType), JsonBool(True, None))),
        ))
      }),
      it("Object type", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"object\"}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("{\"a\":124,\"b\":\"c\"}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Object(types.AnyType), JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Object(types.AnyType),
            JsonNumber(Some(1), None, None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Object(types.AnyType),
            JsonArray(dict.new(), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Object(types.AnyType),
            JsonString("null", None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Object(types.AnyType), JsonBool(True, None))),
        ))
      }),
    ]),

    describe("Multiple type validity", [
      it("Is valid", fn() {
        let schema =
          schema2.get_validator("{\"type\":[\"null\"]}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":[\"null\",\"string\"]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("Isn't valid", fn() {
        let schema = schema2.get_validator("{\"type\":[]}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.NoType, JsonString("null", None))),
        ))
        let schema =
          schema2.get_validator("{\"type\":[\"null\"]}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, JsonString("null", None))),
        ))
        let schema =
          schema2.get_validator("{\"type\":[\"null\",\"string\"]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(
            MultipleInfo([
              IncorrectType(types.Null, JsonNumber(Some(123), None, None)),
              IncorrectType(types.String, JsonNumber(Some(123), None, None)),
            ]),
          ),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(
            MultipleInfo([
              IncorrectType(types.Null, JsonArray(dict.from_list([]), None)),
              IncorrectType(types.String, JsonArray(dict.from_list([]), None)),
            ]),
          ),
        ))
      }),
    ]),
  ])
}

pub fn schema_number_tests() {
  describe("Numeric Comparison Tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"minimum\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"minimum\":99999}") |> expect.to_be_ok
        schema2.get_validator("{\"minimum\":-99999}") |> expect.to_be_ok
        schema2.get_validator("{\"maximum\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"maximum\":99999}") |> expect.to_be_ok
        schema2.get_validator("{\"maximum\":-99999}") |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMinimum\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMinimum\":99999}") |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMinimum\":-99999}")
        |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMaximum\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMaximum\":99999}") |> expect.to_be_ok
        schema2.get_validator("{\"exclusiveMaximum\":-99999}")
        |> expect.to_be_ok
        schema2.get_validator("{\"multipleOf\":1}") |> expect.to_be_ok
        schema2.get_validator("{\"multipleOf\":10}") |> expect.to_be_ok
        schema2.get_validator("{\"multipleOf\":1.5}") |> expect.to_be_ok
        Nil
      }),
      it("Invalid Schema", fn() {
        schema2.get_validator("{\"minimum\":null}") |> expect.to_be_error
        schema2.get_validator("{\"maximum\":null}") |> expect.to_be_error
        schema2.get_validator("{\"exclusiveMinimum\":null}")
        |> expect.to_be_error
        schema2.get_validator("{\"exclusiveMaximum\":null}")
        |> expect.to_be_error
        schema2.get_validator("{\"multipleOf\":0}") |> expect.to_be_error
        schema2.get_validator("{\"multipleOf\":-9.9}") |> expect.to_be_error
        //error
        schema2.get_validator("{\"multipleOf\":-99999}") |> expect.to_be_error
        //error
        Nil
      }),
    ]),
    describe("minimum tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"minimum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"minimum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"minimum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema = schema2.get_validator("{\"minimum\":1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"minimum\":2.0}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"minimum\":2.1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2.1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"minimum\":-1.5}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"minimum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(1), None, None),
            "minimum",
            JsonNumber(Some(0), None, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"minimum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(-1), None, None),
            "minimum",
            JsonNumber(None, Some(-1.1), None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"minimum\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("3")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(5), None, None),
            "minimum",
            JsonNumber(Some(3), None, None),
          )),
        ))
      }),
    ]),
    describe("exclusiveMinimum tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMinimum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMinimum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMinimum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMinimum\":1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1.01")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMinimum\":2.0}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2.01")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMinimum\":2.1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2.11")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMinimum\":-1.5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1.4")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMinimum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(0), None, None),
            "exclusiveMinimum",
            JsonNumber(Some(0), None, None),
          )),
        ))
        let schema =
          schema2.get_validator(
            "{\"type\":\"number\",\"exclusiveMinimum\":-1.1}",
          )
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(None, Some(-1.1), None),
            "exclusiveMinimum",
            JsonNumber(None, Some(-1.1), None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"exclusiveMinimum\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("3")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(5), None, None),
            "exclusiveMinimum",
            JsonNumber(Some(3), None, None),
          )),
        ))
      }),
    ]),
    describe("maximum tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"maximum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"maximum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"maximum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema = schema2.get_validator("{\"maximum\":2}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"maximum\":2.0}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"maximum\":2.1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2.1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"maximum\":-1.5}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"maximum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(1), None, None),
            "maximum",
            JsonNumber(Some(2), None, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"maximum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-0.9")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(-1), None, None),
            "maximum",
            JsonNumber(None, Some(-0.9), None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"maximum\":3}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("5")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(3), None, None),
            "maximum",
            JsonNumber(Some(5), None, None),
          )),
        ))
      }),
    ]),
    describe("exclusiveMaximum tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMaximum\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMaximum\":-1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-2")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMaximum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMaximum\":1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0.99")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMaximum\":2.0}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("1.99")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMaximum\":2.1}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("2.09")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"exclusiveMaximum\":-1.5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1.6")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"exclusiveMaximum\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(0), None, None),
            "exclusiveMaximum",
            JsonNumber(Some(0), None, None),
          )),
        ))
        let schema =
          schema2.get_validator(
            "{\"type\":\"number\",\"exclusiveMaximum\":-1.1}",
          )
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-1.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(None, Some(-1.1), None),
            "exclusiveMaximum",
            JsonNumber(None, Some(-1.1), None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"exclusiveMaximum\":3}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("5")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(3), None, None),
            "exclusiveMaximum",
            JsonNumber(Some(5), None, None),
          )),
        ))
      }),
    ]),
    describe("multipleOf tests", [
      it("is multiple", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("5")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":2.2}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("4.4")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":0.1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("3")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-10")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":3.0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("9")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("55.0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("not multiple", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("11")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(ValidationError("11 is not multiple of 5")),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":2}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-11")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(ValidationError("-11 is not multiple of 2")),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5.0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("-11")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(ValidationError("-11 is not multiple of 5")),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("11.0")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(ValidationError("11 is not multiple of 5")),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"number\",\"multipleOf\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("5.1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(ValidationError("5.1 is not multiple of 5")),
        ))
      }),
    ]),
  ])
}

pub fn schema_string_tests() {
  describe("String Comparison Tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"minLength\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"minLength\":999}") |> expect.to_be_ok
        schema2.get_validator("{\"maxLength\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"maxLength\":999}") |> expect.to_be_ok
        schema2.get_validator("{\"pattern\":\"regexy\"}") |> expect.to_be_ok
        schema2.get_validator("{\"pattern\":\"reg\\nexy\"}") |> expect.to_be_ok
        Nil
      }),
      it("Invalid Schema", fn() {
        schema2.get_validator("{\"minLength\":0.5}") |> expect.to_be_error
        schema2.get_validator("{\"minLength\":-1}") |> expect.to_be_error
        schema2.get_validator("{\"minLength\":true}") |> expect.to_be_error
        schema2.get_validator("{\"maxLength\":0.5}") |> expect.to_be_error
        schema2.get_validator("{\"maxLength\":-1}") |> expect.to_be_error
        schema2.get_validator("{\"maxLength\":true}") |> expect.to_be_error
        schema2.get_validator("{\"pattern\":\"reg\\dexy\"}")
        |> expect.to_be_error
        schema2.get_validator("{\"pattern\":123}")
        |> expect.to_be_error
        Nil
      }),
    ]),
    describe("minimum length tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"minLength\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"minLength\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"minLength\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"minLength\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(1), None, None),
            "minLength",
            JsonString("", None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"minLength\":5555}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(5555), None, None),
            "minLength",
            JsonString("", None),
          )),
        ))
      }),
    ]),
    describe("maximum length tests", [
      it("should pass", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"maxLength\":5}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"maxLength\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"maxLength\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("should fail", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"maxLength\":1}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(1), None, None),
            "maxLength",
            JsonString("1234", None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"maxLength\":0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(0), None, None),
            "maxLength",
            JsonString("1", None),
          )),
        ))
      }),
    ]),
    describe("pattern tests", [
      it("should match", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"pattern\":\"\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"pattern\":\"123\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"pattern\":\"^1234$\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("shouldn't match", fn() {
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"pattern\":\"a\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"1234\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonString("a", None),
            "pattern",
            JsonString("1234", None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"type\":\"string\",\"pattern\":\"^1234$\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"123\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonString("^1234$", None),
            "pattern",
            JsonString("123", None),
          )),
        ))
      }),
    ]),
  ])
}

pub fn schema_const_tests() {
  describe("Const Tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"const\":0}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":null}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":\"s\"}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":true}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":[]}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":{}}") |> expect.to_be_ok
        schema2.get_validator("{\"const\":{\"a\":123}}") |> expect.to_be_ok
        Nil
      }),
    ]),
    describe("Actual Tests", [
      it("passes", fn() {
        let schema =
          schema2.get_validator("{\"const\":123}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":123}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123.0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":123.0}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":true}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":null}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("null")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":\"const\"}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"const\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":[]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":[0.0]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[0]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":[0]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[0.0]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":[[[[[[[]]]]]]]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[[[[[[[]]]]]]]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":[1,2,3,4]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[1,2,3,4]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":{}}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"const\":{\"abc\":123,\"def\":null}}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{\"abc\":123,\"def\":null}")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("fails", fn() {
        let schema =
          schema2.get_validator("{\"const\":123}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("124")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(123), None, None),
            "equal",
            JsonNumber(Some(124), None, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"const\":null}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("124")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNull(None),
            "equal",
            JsonNumber(Some(124), None, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"const\":true}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("false")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonBool(True, None),
            "equal",
            JsonBool(False, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"const\":[1,2,3]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[1,2,4]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonArray(
              dict.from_list([
                #(0, JsonNumber(Some(1), None, None)),
                #(1, JsonNumber(Some(2), None, None)),
                #(2, JsonNumber(Some(3), None, None)),
              ]),
              None,
            ),
            "equal",
            JsonArray(
              dict.from_list([
                #(0, JsonNumber(Some(1), None, None)),
                #(1, JsonNumber(Some(2), None, None)),
                #(2, JsonNumber(Some(4), None, None)),
              ]),
              None,
            ),
          )),
        ))
      }),
    ]),
  ])
}

pub fn schema_enum_tests() {
  describe("Enum Tests", [
    describe("Schema Test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"enum\":[0]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[null]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[\"s\"]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[true]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[[]]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[{}]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[{\"a\":123}]}") |> expect.to_be_ok
        schema2.get_validator("{\"enum\":[{\"a\":123},321,\"a\"]}")
        |> expect.to_be_ok
        Nil
      }),
      it("Invalid Schema", fn() {
        schema2.get_validator("{\"enum\":[]}") |> expect.to_be_error
        schema2.get_validator("{\"enum\":[true, true]}") |> expect.to_be_error
        schema2.get_validator("{\"enum\":[1,2,3,1]}") |> expect.to_be_error
        schema2.get_validator("{\"enum\":[1,2,true,\"1\", 2]}")
        |> expect.to_be_error
        Nil
      }),
    ]),
    describe("Actual Test", [
      it("Passes", fn() {
        let schema =
          schema2.get_validator("{\"enum\":[123]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[123.0]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[123]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("123.0")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[false]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("false")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[123,999,true]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[\"123\"]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"123\"")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[[[[123]]]]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[[[123]]]")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
        let schema =
          schema2.get_validator("{\"enum\":[{\"123\":{}}]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("{\"123\":{}}")
        validator2.validate(json, schema) |> expect.to_equal(#(True, None))
      }),
      it("Fails", fn() {
        let schema =
          schema2.get_validator("{\"enum\":[123]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("124")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(InvalidComparison(
            JsonNumber(Some(123), None, None),
            "equal",
            JsonNumber(Some(124), None, None),
          )),
        ))
        let schema =
          schema2.get_validator("{\"enum\":[123, false]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(
            MultipleInfo([
              InvalidComparison(
                JsonBool(False, None),
                "equal",
                JsonBool(True, None),
              ),
              InvalidComparison(
                JsonNumber(Some(123), None, None),
                "equal",
                JsonBool(True, None),
              ),
            ]),
          ),
        ))
        let schema =
          schema2.get_validator("{\"enum\":[123, [[[false]]]]}")
          |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("[[false]]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(
            MultipleInfo([
              InvalidComparison(
                JsonArray(
                  dict.from_list([
                    #(
                      0,
                      JsonArray(
                        dict.from_list([
                          #(
                            0,
                            JsonArray(
                              dict.from_list([#(0, JsonBool(False, None))]),
                              None,
                            ),
                          ),
                        ]),
                        None,
                      ),
                    ),
                  ]),
                  None,
                ),
                "equal",
                JsonArray(
                  dict.from_list([
                    #(
                      0,
                      JsonArray(
                        dict.from_list([#(0, JsonBool(False, None))]),
                        None,
                      ),
                    ),
                  ]),
                  None,
                ),
              ),
              InvalidComparison(
                JsonNumber(Some(123), None, None),
                "equal",
                JsonArray(
                  dict.from_list([
                    #(
                      0,
                      JsonArray(
                        dict.from_list([#(0, JsonBool(False, None))]),
                        None,
                      ),
                    ),
                  ]),
                  None,
                ),
              ),
            ]),
          ),
        ))
      }),
    ]),
  ])
}

pub fn suite_tests() {
  simplifile.get_files("./test/schema_json")
  |> expect.to_be_ok
  |> list.map(fn(filename) {
    case
      simplifile.read(filename)
      |> expect.to_be_ok
      |> simplejson.parse
      |> expect.to_be_ok
    {
      JsonObject(items, _) -> {
        Ok(describe(
          filename,
          dict.map_values(items, fn(k, v) {
            case k {
              "valid" -> {
                case v {
                  JsonArray(l, _) -> {
                    Some(
                      it(k <> " (" <> int.to_string(dict.size(l)) <> ")", fn() {
                        list.each(
                          stringify.dict_to_ordered_list(l),
                          fn(test_json) {
                            schema2.get_validator_from_json(test_json)
                            |> expect.to_be_ok
                          },
                        )
                      }),
                    )
                  }
                  _ -> None
                }
              }
              "invalid" -> {
                case v {
                  JsonArray(l, _) -> {
                    Some(
                      it(k <> " (" <> int.to_string(dict.size(l)) <> ")", fn() {
                        list.each(
                          stringify.dict_to_ordered_list(l),
                          fn(test_json) {
                            schema2.get_validator_from_json(test_json)
                            |> expect.to_be_error
                          },
                        )
                      }),
                    )
                  }
                  _ -> None
                }
              }
              "tests_pass" -> {
                case v {
                  JsonArray(l, _) -> {
                    Some(
                      it(k <> " (" <> int.to_string(dict.size(l)) <> ")", fn() {
                        list.each(
                          stringify.dict_to_ordered_list(l),
                          fn(test_json) {
                            case test_json {
                              JsonObject(test_json, _) -> {
                                case
                                  dict.get(test_json, "schema"),
                                  dict.get(test_json, "test")
                                {
                                  Ok(schema), Ok(to_test) -> {
                                    schema2.get_validator_from_json(schema)
                                    |> expect.to_be_ok
                                    |> validator2.validate(to_test, _)
                                    |> expect.to_equal(#(True, None))
                                  }
                                  _, _ -> Nil
                                }
                              }
                              _ -> Nil
                            }
                          },
                        )
                      }),
                    )
                  }
                  _ -> None
                }
              }
              "tests_fail" -> {
                case v {
                  JsonArray(l, _) -> {
                    Some(
                      it(k <> " (" <> int.to_string(dict.size(l)) <> ")", fn() {
                        list.each(
                          stringify.dict_to_ordered_list(l),
                          fn(test_json) {
                            case test_json {
                              JsonObject(test_json, _) -> {
                                case
                                  dict.get(test_json, "schema"),
                                  dict.get(test_json, "test")
                                {
                                  Ok(schema), Ok(to_test) -> {
                                    let res =
                                      schema2.get_validator_from_json(schema)
                                      |> expect.to_be_ok
                                      |> validator2.validate(to_test, _)

                                    expect.to_be_some(res.1)
                                    expect.to_be_false(res.0)
                                  }
                                  _, _ -> Nil
                                }
                              }
                              _ -> Nil
                            }
                          },
                        )
                      }),
                    )
                  }
                  _ -> None
                }
              }
              _ -> panic
            }
          })
            |> dict.values
            |> option.values,
        ))
      }
      _ -> Error(Nil)
    }
  })
  |> result.values
  |> describe("Schema testfiles", _)
}
