import gleam/dict
import gleam/option.{None, Some}
import simplejson
import simplejson/jsonvalue.{JsonArray, JsonNumber, JsonString, NoMD}
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn pointer_tests() {
  let assert Ok(basic_json) =
    simplejson.parse(
      "{
        \"foo\": [\"bar\", \"baz\"],
        \"\": 0,
        \"a/b\": 1,
        \"c%d\": 2,
        \"e^f\": 3,
        \"g|h\": 4,
        \"i\\\\j\": 5,
        \"k\\\"l\": 6,
        \" \": 7,
        \"m~n\": 8,
        \"o~1p\": 9
     }",
    )

  describe("JSON Pointer tests", [
    describe("normal path", [
      it("test 1", fn() {
        simplejson.apply_pointer(basic_json, "")
        |> expect.to_be_ok
        |> expect.to_equal(basic_json)
        Nil
      }),
      it("test 2", fn() {
        simplejson.apply_pointer(basic_json, "/foo")
        |> expect.to_be_ok
        |> expect.to_equal(JsonArray(
          NoMD,
          dict.from_list([
            #(0, JsonString(NoMD, "bar")),
            #(1, JsonString(NoMD, "baz")),
          ]),
        ))
        Nil
      }),
      it("test 3", fn() {
        simplejson.apply_pointer(basic_json, "/foo/0")
        |> expect.to_be_ok
        |> expect.to_equal(JsonString(NoMD, "bar"))
        Nil
      }),
      it("test 4", fn() {
        simplejson.apply_pointer(basic_json, "/")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(0), None, Some("0")))
        Nil
      }),
      it("test 5", fn() {
        simplejson.apply_pointer(basic_json, "/a~1b")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(1), None, Some("1")))
        Nil
      }),
      it("test 6", fn() {
        simplejson.apply_pointer(basic_json, "/c%d")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(2), None, Some("2")))
        Nil
      }),
      it("test 7", fn() {
        simplejson.apply_pointer(basic_json, "/e^f")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(3), None, Some("3")))
        Nil
      }),
      it("test 8", fn() {
        simplejson.apply_pointer(basic_json, "/g|h")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(4), None, Some("4")))
        Nil
      }),
      it("test 9", fn() {
        simplejson.apply_pointer(basic_json, "/i\\\\j")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(5), None, Some("5")))
        Nil
      }),
      it("test 10", fn() {
        simplejson.apply_pointer(basic_json, "/k\\\"l")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(6), None, Some("6")))
        Nil
      }),
      it("test 11", fn() {
        simplejson.apply_pointer(basic_json, "/ ")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(7), None, Some("7")))
        Nil
      }),
      it("test 12", fn() {
        simplejson.apply_pointer(basic_json, "/m~0n")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(8), None, Some("8")))
        Nil
      }),
      it("escape ordering", fn() {
        simplejson.apply_pointer(basic_json, "/o~01p")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(9), None, Some("9")))
        Nil
      }),
    ]),
    describe("URI fragment", [
      it("test 1", fn() {
        simplejson.apply_pointer(basic_json, "#")
        |> expect.to_be_ok
        |> expect.to_equal(basic_json)
        Nil
      }),
      it("test 2", fn() {
        simplejson.apply_pointer(basic_json, "#/foo")
        |> expect.to_be_ok
        |> expect.to_equal(JsonArray(
          NoMD,
          dict.from_list([
            #(0, JsonString(NoMD, "bar")),
            #(1, JsonString(NoMD, "baz")),
          ]),
        ))
        Nil
      }),
      it("test 3", fn() {
        simplejson.apply_pointer(basic_json, "#/foo/0")
        |> expect.to_be_ok
        |> expect.to_equal(JsonString(NoMD, "bar"))
        Nil
      }),
      it("test 4", fn() {
        simplejson.apply_pointer(basic_json, "#/")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(0), None, Some("0")))
        Nil
      }),
      it("test 5", fn() {
        simplejson.apply_pointer(basic_json, "#/a~1b")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(1), None, Some("1")))
        Nil
      }),
      it("test 6", fn() {
        simplejson.apply_pointer(basic_json, "#/c%25d")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(2), None, Some("2")))
        Nil
      }),
      it("test 7", fn() {
        simplejson.apply_pointer(basic_json, "#/e%5Ef")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(3), None, Some("3")))
        Nil
      }),
      it("test 8", fn() {
        simplejson.apply_pointer(basic_json, "#/g%7Ch")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(4), None, Some("4")))
        Nil
      }),
      it("test 9", fn() {
        simplejson.apply_pointer(basic_json, "#/i%5Cj")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(5), None, Some("5")))
        Nil
      }),
      it("test 10", fn() {
        simplejson.apply_pointer(basic_json, "#/k%22l")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(6), None, Some("6")))
        Nil
      }),
      it("test 11", fn() {
        simplejson.apply_pointer(basic_json, "#/%20")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(7), None, Some("7")))
        Nil
      }),
      it("test 12", fn() {
        simplejson.apply_pointer(basic_json, "#/m~0n")
        |> expect.to_be_ok
        |> expect.to_equal(JsonNumber(NoMD, Some(8), None, Some("8")))
        Nil
      }),
    ]),
  ])
}
