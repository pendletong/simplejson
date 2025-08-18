import gleam/dict
import gleam/option.{None, Some}
import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/types.{
  AlwaysFail, IncorrectType, InvalidComparison, MultipleInfo, StringValue,
  ValidationError,
}
import simplejson/internal/schema2/validator2
import simplejson/jsonvalue.{JsonArray, JsonNumber, JsonString}
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
          Some(IncorrectType(
            types.Null,
            JsonNumber(Some(1), None, Some("1"), None),
          )),
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
          Some(IncorrectType(types.Null, jsonvalue.JsonObject(dict.new(), None))),
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
          Some(IncorrectType(types.Null, jsonvalue.JsonBool(True, None))),
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
          Some(IncorrectType(types.String, jsonvalue.JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.String,
            JsonNumber(Some(1), None, Some("1"), None),
          )),
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
          Some(IncorrectType(
            types.String,
            jsonvalue.JsonObject(dict.new(), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.String, jsonvalue.JsonBool(True, None))),
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
          Some(IncorrectType(
            types.Integer,
            JsonNumber(None, Some(2.1), Some("2.1"), None),
          )),
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
          Some(IncorrectType(types.Integer, jsonvalue.JsonNull(None))),
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
          Some(IncorrectType(
            types.Integer,
            jsonvalue.JsonObject(dict.new(), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Integer, jsonvalue.JsonBool(True, None))),
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
          Some(IncorrectType(types.Number, jsonvalue.JsonNull(None))),
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
          Some(IncorrectType(
            types.Number,
            jsonvalue.JsonObject(dict.new(), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("true")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Number, jsonvalue.JsonBool(True, None))),
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
          Some(IncorrectType(types.Boolean, jsonvalue.JsonNull(None))),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Boolean,
            JsonNumber(Some(1), None, Some("1"), None),
          )),
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
          Some(IncorrectType(
            types.Boolean,
            jsonvalue.JsonObject(dict.new(), None),
          )),
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
          Some(IncorrectType(
            types.Array(types.AnyType),
            jsonvalue.JsonNull(None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Array(types.AnyType),
            JsonNumber(Some(1), None, Some("1"), None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("{}")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Array(types.AnyType),
            jsonvalue.JsonObject(dict.new(), None),
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
          Some(IncorrectType(
            types.Array(types.AnyType),
            jsonvalue.JsonBool(True, None),
          )),
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
          Some(IncorrectType(
            types.Object(types.AnyType),
            jsonvalue.JsonNull(None),
          )),
        ))
        let assert Ok(json) = simplejson.parse("1")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(
            types.Object(types.AnyType),
            JsonNumber(Some(1), None, Some("1"), None),
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
          Some(IncorrectType(
            types.Object(types.AnyType),
            jsonvalue.JsonBool(True, None),
          )),
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
              IncorrectType(
                types.String,
                JsonNumber(Some(123), None, Some("123"), None),
              ),
              IncorrectType(
                types.Null,
                JsonNumber(Some(123), None, Some("123"), None),
              ),
            ]),
          ),
        ))
        let assert Ok(json) = simplejson.parse("[]")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(
            MultipleInfo([
              IncorrectType(types.String, JsonArray(dict.from_list([]), None)),
              IncorrectType(types.Null, JsonArray(dict.from_list([]), None)),
            ]),
          ),
        ))
      }),
    ]),
  ])
}

pub fn schema_number_tests() {
  describe("numeric comparison tests", [
    describe("Schema test", [
      it("Valid Schema", fn() {
        schema2.get_validator("{\"minimum\":0}") |> expect.to_be_ok |> echo
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
            types.NumberValue("minimum", Some(1), None),
            "minimum",
            JsonNumber(Some(0), None, Some("0"), None),
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
            types.NumberValue("minimum", Some(-1), None),
            "minimum",
            JsonNumber(None, Some(-1.1), Some("-1.1"), None),
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
            types.NumberValue("minimum", Some(5), None),
            "minimum",
            JsonNumber(Some(3), None, Some("3"), None),
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
            types.NumberValue("exclusiveMinimum", Some(0), None),
            "exclusiveMinimum",
            JsonNumber(Some(0), None, Some("0"), None),
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
            types.NumberValue("exclusiveMinimum", None, Some(-1.1)),
            "exclusiveMinimum",
            JsonNumber(None, Some(-1.1), Some("-1.1"), None),
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
            types.NumberValue("exclusiveMinimum", Some(5), None),
            "exclusiveMinimum",
            JsonNumber(Some(3), None, Some("3"), None),
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
            types.NumberValue("maximum", Some(1), None),
            "maximum",
            JsonNumber(Some(2), None, Some("2"), None),
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
            types.NumberValue("maximum", Some(-1), None),
            "maximum",
            JsonNumber(None, Some(-0.9), Some("-0.9"), None),
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
            types.NumberValue("maximum", Some(3), None),
            "maximum",
            JsonNumber(Some(5), None, Some("5"), None),
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
            types.NumberValue("exclusiveMaximum", Some(0), None),
            "exclusiveMaximum",
            JsonNumber(Some(0), None, Some("0"), None),
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
            types.NumberValue("exclusiveMaximum", None, Some(-1.1)),
            "exclusiveMaximum",
            JsonNumber(None, Some(-1.1), Some("-1.1"), None),
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
            types.NumberValue("exclusiveMaximum", Some(3), None),
            "exclusiveMaximum",
            JsonNumber(Some(5), None, Some("5"), None),
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
          Some(ValidationError("11.0 is not multiple of 5")),
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
  describe("string comparison tests", [
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
            types.NumberValue("minLength", Some(1), None),
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
            types.NumberValue("minLength", Some(5555), None),
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
            types.NumberValue("maxLength", Some(1), None),
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
            types.NumberValue("maxLength", Some(0), None),
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
            StringValue("pattern", "a"),
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
            StringValue("pattern", "^1234$"),
            "pattern",
            JsonString("123", None),
          )),
        ))
      }),
    ]),
  ])
}
