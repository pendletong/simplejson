import gleam/list
import gleam/option.{None, Some}
import simplejson/internal/schema/schema
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, IntProperty, NumberProperty,
  StringProperty,
}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn schema_string_tests() {
  describe("Schema String Tests", [
    it("Basic String Match", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\"}")
      |> expect.to_equal(#(True, []))
    }),
    it("Basic String Fail", fn() {
      let #(pass, errors) = schema.validate("123", "{\"type\":\"string\"}")
      pass |> expect.to_be_false
      contains_invalid_data_type_error(errors) |> expect.to_be_true
    }),
    it("Basic String Min Length", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\", \"minLength\":3}")
      |> expect.to_equal(#(True, []))
    }),
    it("Basic String Min Length Fail", fn() {
      let #(pass, errors) =
        schema.validate("\"123-567\"", "{\"type\":\"string\", \"minLength\":8}")
      pass |> expect.to_be_false
      contains_failed_property_error(errors, IntProperty("minLength", 8))
      |> expect.to_be_true
    }),
    it("Basic String Max Length", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\", \"maxLength\":8}")
      |> expect.to_equal(#(True, []))
    }),
    it("Basic String Max Length Fail", fn() {
      let #(pass, errors) =
        schema.validate("\"123-567\"", "{\"type\":\"string\", \"maxLength\":3}")
      pass |> expect.to_be_false
      contains_failed_property_error(errors, IntProperty("maxLength", 3))
      |> expect.to_be_true
    }),
    it("Basic String Pattern", fn() {
      schema.validate(
        "\"123-567\"",
        "{\"type\":\"string\", \"pattern\":\"[0-9]{3}-[0-9]{3}\"}",
      )
      |> expect.to_equal(#(True, []))
    }),
    it("Basic String Pattern Fail", fn() {
      let #(pass, errors) =
        schema.validate(
          "\"123-567\"",
          "{\"type\":\"string\", \"pattern\":\"text\"}",
        )
      pass |> expect.to_be_false
      contains_failed_property_error(errors, StringProperty("pattern", "text"))
      |> expect.to_be_true
    }),
  ])
}

pub fn schema_number_tests() {
  describe("Schema Number Tests", [
    describe("Basic Numbers", [
      it("Basic Number(Int) Match", fn() {
        schema.validate("123", "{\"type\":\"number\"}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number(Float) Match", fn() {
        schema.validate("123.5", "{\"type\":\"number\"}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Fail", fn() {
        let #(pass, errors) =
          schema.validate("\"123\"", "{\"type\":\"number\"}")
        pass |> expect.to_be_false
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Minimum Properties", [
      it("Basic Number Minimum Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"minimum\":100}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Minimum Float/Int Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"minimum\":100.5}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Minimum Float/Int 2 Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"minimum\":122.99}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Minimum Exact Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"minimum\":123.5}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Exclusive Minimum Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMinimum\":100}",
        )
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Exclusive Minimum Exact Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMinimum\":123.4}",
        )
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Minimum Exact Property Fail", fn() {
        let #(pass, errors) =
          schema.validate("123.5", "{\"type\":\"number\", \"minimum\":123.6}")
        pass |> expect.to_be_false
        contains_failed_property_error(
          errors,
          NumberProperty("minimum", None, Some(123.6)),
        )
        |> expect.to_be_true
      }),
      it("Basic Number Exclusive Minimum Property Fail", fn() {
        let #(pass, errors) =
          schema.validate(
            "123.5",
            "{\"type\":\"number\", \"exclusiveMinimum\":123.5}",
          )
        pass |> expect.to_be_false
        contains_failed_property_error(
          errors,
          NumberProperty("exclusiveMinimum", None, Some(123.5)),
        )
        |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Maximum Properties", [
      it("Basic Number Maximum Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"maximum\":200}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Maximum Float/Int Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"maximum\":200.5}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Maximum Float/Int 2 Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"maximum\":123.01}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Maximum Exact Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"maximum\":123.5}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Exclusive Maximum Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMaximum\":200}",
        )
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Exclusive Maximum Exact Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMaximum\":123.6}",
        )
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Maximum Exact Property Fail", fn() {
        let #(pass, errors) =
          schema.validate("123.5", "{\"type\":\"number\", \"maximum\":123.4}")
        pass |> expect.to_be_false
        contains_failed_property_error(
          errors,
          NumberProperty("maximum", None, Some(123.4)),
        )
        |> expect.to_be_true
      }),
      it("Basic Number Exclusive Maximum Property Fail", fn() {
        let #(pass, errors) =
          schema.validate(
            "123.5",
            "{\"type\":\"number\", \"exclusiveMaximum\":123.5}",
          )
        pass |> expect.to_be_false
        contains_failed_property_error(
          errors,
          NumberProperty("exclusiveMaximum", None, Some(123.5)),
        )
        |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Multiples", [
      it("Basic Number Multiple Property", fn() {
        schema.validate("125", "{\"type\":\"number\", \"multipleOf\":25}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Multiple Float Property", fn() {
        schema.validate("125", "{\"type\":\"number\", \"multipleOf\":6.25}")
        |> expect.to_equal(#(True, []))
      }),
      it("Basic Number Multiple Property Fails", fn() {
        let #(pass, errors) =
          schema.validate("125", "{\"type\":\"number\", \"multipleOf\":20}")
        pass |> expect.to_be_false
        contains_failed_property_error(
          errors,
          NumberProperty("multipleOf", Some(20), None),
        )
        |> expect.to_be_true
      }),
      it("Basic Float Multiple Property", fn() {
        schema.validate("10.8", "{\"type\":\"number\", \"multipleOf\":3.6}")
        |> expect.to_equal(#(True, []))
      }),
    ]),
  ])
}

fn contains_invalid_data_type_error(errors: List(InvalidEntry)) -> Bool {
  let err =
    errors
    |> list.find(fn(err) {
      case err {
        types.InvalidDataType(_) -> True
        _ -> False
      }
    })
  case err {
    Ok(_) -> True
    _ -> False
  }
}

fn contains_failed_property_error(
  errors: List(InvalidEntry),
  fail_prop: ValidationProperty,
) -> Bool {
  let err =
    errors
    |> list.find(fn(err) {
      case err {
        types.FailedProperty(prop, _) -> {
          prop == fail_prop
        }
        _ -> False
      }
    })
  case err {
    Ok(_) -> True
    _ -> False
  }
}
