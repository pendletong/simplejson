import gleam/dict
import gleam/option.{None, Some}
import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/types.{
  AlwaysFail, IncorrectType, MultipleInfo,
}
import simplejson/internal/schema2/validator2
import simplejson/jsonvalue.{JsonArray, JsonNumber}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn schema_basic_tests() {
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
  ])
}

pub fn schema_type_tests() {
  describe("Type tests", [
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
          Some(IncorrectType(types.Null, jsonvalue.JsonString("null", None))),
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
          Some(IncorrectType(types.Integer, jsonvalue.JsonString("null", None))),
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
          Some(IncorrectType(types.Number, jsonvalue.JsonString("null", None))),
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
          Some(IncorrectType(types.Boolean, jsonvalue.JsonString("null", None))),
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
            jsonvalue.JsonString("null", None),
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
            jsonvalue.JsonString("null", None),
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
        let schema =
          schema2.get_validator("{\"type\":[\"null\"]}") |> expect.to_be_ok
        let assert Ok(json) = simplejson.parse("\"null\"")
        validator2.validate(json, schema)
        |> expect.to_equal(#(
          False,
          Some(IncorrectType(types.Null, jsonvalue.JsonString("null", None))),
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
