import gleam/list
import simplejson/internal/schema/schema
import simplejson/internal/schema/types
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
      errors
      |> list.find(fn(err) {
        case err {
          types.InvalidDataType(_) -> True
          _ -> False
        }
      })
      |> expect.to_be_ok
      Nil
    }),
  ])
}
