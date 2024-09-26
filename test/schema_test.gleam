import gleam/io
import gleam/list
import simplejson/internal/schema/schema
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, IntProperty, StringProperty,
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
          io.debug(#("matching", fail_prop, prop))
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
