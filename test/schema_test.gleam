import gleam/list
import gleam/option.{None, Some}
import simplejson/internal/schema/error.{
  type InvalidEntry, FailedProperty, FalseSchema, InvalidDataType, NotMatchEnum,
}
import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, BooleanValue, IntValue, NumberValue, StringValue,
}
import simplejson/internal/schema/schema
import startest.{describe, it}
import startest/expect

pub fn main() {
  startest.run(startest.default_config())
}

pub fn schema_types_tests() {
  describe("Schema Types Tests", [
    describe("Single Types", [
      it("String Match", fn() {
        schema.validate("\"123-567\"", "{\"type\":\"string\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("String Fail", fn() {
        let errors =
          schema.validate("123", "{\"type\":\"string\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Number Match", fn() {
        schema.validate("12", "{\"type\":\"number\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Number Match 2", fn() {
        schema.validate("12.3", "{\"type\":\"number\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Number Fail", fn() {
        let errors =
          schema.validate("\"123\"", "{\"type\":\"number\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Integer Match", fn() {
        schema.validate("12", "{\"type\":\"integer\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Integer Fail", fn() {
        let errors =
          schema.validate("\"123\"", "{\"type\":\"integer\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Integer Fail 2", fn() {
        let errors =
          schema.validate("123.4", "{\"type\":\"integer\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Boolean Match", fn() {
        schema.validate("true", "{\"type\":\"boolean\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Boolean Match 2", fn() {
        schema.validate("false", "{\"type\":\"boolean\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Boolean Fail", fn() {
        let errors =
          schema.validate("123", "{\"type\":\"boolean\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Null Match", fn() {
        schema.validate("null", "{\"type\":\"null\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Null Fail", fn() {
        let errors =
          schema.validate("\"123\"", "{\"type\":\"null\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      it("Array Match", fn() {
        schema.validate("[1,2,3]", "{\"type\":\"array\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Array Fail", fn() {
        let errors =
          schema.validate("\"[1,2,3]\"", "{\"type\":\"array\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
    describe("Multiple Types", [
      it("Multiple Match", fn() {
        schema.validate("null", "{\"type\":[\"null\",\"string\"]}")
        |> expect.to_equal(Ok(True))
      }),
      it("Multiple Match 2", fn() {
        schema.validate("\"123\"", "{\"type\":[\"null\",\"string\"]}")
        |> expect.to_equal(Ok(True))
      }),
      it("Multiple Fail", fn() {
        let errors =
          schema.validate("123", "{\"type\":[\"null\",\"string\"]}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn schema_enum_tests() {
  describe("Schema Enum Tests", [
    it("Basic Enum Match", fn() {
      schema.validate("1", "{\"enum\":[1,2,3]}")
      |> expect.to_equal(Ok(True))
    }),
    it("Basic Enum Match", fn() {
      schema.validate("\"2\"", "{\"enum\":[1,\"2\",3]}")
      |> expect.to_equal(Ok(True))
    }),
    it("Object Enum Match", fn() {
      schema.validate("{\"test\":2}", "{\"enum\":[1,2,{\"test\":2}]}")
      |> expect.to_equal(Ok(True))
    }),
    it("Object Enum Match", fn() {
      schema.validate(
        "{\"test\":2,\"test2\":true}",
        "{\"enum\":[1,2,{\"test\":2,\"test2\":true}]}",
      )
      |> expect.to_equal(Ok(True))
    }),
    it("Object Enum Match", fn() {
      schema.validate(
        "{\"test\":2,\"test2\":true}",
        "{\"enum\":[1,2,{\"test2\":true,\"test\":2}]}",
      )
      |> expect.to_equal(Ok(True))
    }),
    it("Object Enum Fail", fn() {
      let errors =
        schema.validate("{\"test\":3}", "{\"enum\":[1,2,{\"test\":2}]}")
        |> expect.to_be_error
      contains_enum_error(errors)
      |> expect.to_be_true
    }),
    it("Object Enum and Type Fail", fn() {
      let errors =
        schema.validate(
          "{\"test\":3}",
          "{\"type\":\"number\",\"enum\":[1,2,{\"test\":2}]}",
        )
        |> expect.to_be_error
      contains_enum_error(errors)
      |> expect.to_be_true
      contains_invalid_data_type_error(errors) |> expect.to_be_true
    }),
  ])
}

pub fn schema_string_tests() {
  describe("Schema String Tests", [
    it("Basic String Match", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\"}")
      |> expect.to_equal(Ok(True))
    }),
    it("Basic String Fail", fn() {
      let errors =
        schema.validate("123", "{\"type\":\"string\"}")
        |> expect.to_be_error
      contains_invalid_data_type_error(errors) |> expect.to_be_true
    }),
    it("Basic String Min Length", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\", \"minLength\":3}")
      |> expect.to_equal(Ok(True))
    }),
    it("Basic String Min Length Fail", fn() {
      let errors =
        schema.validate("\"123-567\"", "{\"type\":\"string\", \"minLength\":8}")
        |> expect.to_be_error
      contains_failed_property_error(errors, IntValue("minLength", 8))
      |> expect.to_be_true
    }),
    it("Basic String Max Length", fn() {
      schema.validate("\"123-567\"", "{\"type\":\"string\", \"maxLength\":8}")
      |> expect.to_equal(Ok(True))
    }),
    it("Basic String Max Length Fail", fn() {
      let errors =
        schema.validate("\"123-567\"", "{\"type\":\"string\", \"maxLength\":3}")
        |> expect.to_be_error
      contains_failed_property_error(errors, IntValue("maxLength", 3))
      |> expect.to_be_true
    }),
    it("Basic String Pattern", fn() {
      schema.validate(
        "\"123-567\"",
        "{\"type\":\"string\", \"pattern\":\"[0-9]{3}-[0-9]{3}\"}",
      )
      |> expect.to_equal(Ok(True))
    }),
    it("Basic String Pattern Fail", fn() {
      let errors =
        schema.validate(
          "\"123-567\"",
          "{\"type\":\"string\", \"pattern\":\"text\"}",
        )
        |> expect.to_be_error
      contains_failed_property_error(errors, StringValue("pattern", "text"))
      |> expect.to_be_true
    }),
  ])
}

pub fn schema_basic_tests() {
  describe("Schema Basic Tests", [
    describe("Anything", [
      it("Basic Obj Match", fn() {
        schema.validate("[123,5,null]", "{}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic True Match", fn() {
        schema.validate("[false, 5, \"no\"]", "true")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic False Fail", fn() {
        schema.validate("[1,2,3]", "false")
        |> expect.to_be_error
        |> expect.list_to_contain(FalseSchema)
      }),
    ]),
    describe("Null", [
      it("Basic Null Match", fn() {
        schema.validate("null", "{\"type\":\"null\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Null Match Fail", fn() {
        let errors =
          schema.validate("123", "{\"type\":\"null\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
    describe("Boolean", [
      it("Basic True Match", fn() {
        schema.validate("true", "{\"type\":\"boolean\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic False Match", fn() {
        schema.validate("false", "{\"type\":\"boolean\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Bool Match Fail", fn() {
        let errors =
          schema.validate("123", "{\"type\":\"boolean\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn schema_number_tests() {
  describe("Schema Number Tests", [
    describe("Basic Numbers", [
      it("Basic Number(Int) Match", fn() {
        schema.validate("123", "{\"type\":\"number\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number(Float) Match", fn() {
        schema.validate("123.5", "{\"type\":\"number\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Fail", fn() {
        let errors =
          schema.validate("\"123\"", "{\"type\":\"number\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Minimum Properties", [
      it("Basic Number Minimum Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"minimum\":100}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Minimum Float/Int Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"minimum\":100.5}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Minimum Float/Int 2 Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"minimum\":122.99}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Minimum Exact Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"minimum\":123.5}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Exclusive Minimum Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMinimum\":100}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Exclusive Minimum Exact Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMinimum\":123.4}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Minimum Exact Property Fail", fn() {
        let errors =
          schema.validate("123.5", "{\"type\":\"number\", \"minimum\":123.6}")
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          NumberValue("minimum", None, Some(123.6)),
        )
        |> expect.to_be_true
      }),
      it("Basic Number Exclusive Minimum Property Fail", fn() {
        let errors =
          schema.validate(
            "123.5",
            "{\"type\":\"number\", \"exclusiveMinimum\":123.5}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          NumberValue("exclusiveMinimum", None, Some(123.5)),
        )
        |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Maximum Properties", [
      it("Basic Number Maximum Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"maximum\":200}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Maximum Float/Int Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"maximum\":200.5}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Maximum Float/Int 2 Property", fn() {
        schema.validate("123", "{\"type\":\"number\", \"maximum\":123.01}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Maximum Exact Property", fn() {
        schema.validate("123.5", "{\"type\":\"number\", \"maximum\":123.5}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Exclusive Maximum Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMaximum\":200}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Exclusive Maximum Exact Property", fn() {
        schema.validate(
          "123.5",
          "{\"type\":\"number\", \"exclusiveMaximum\":123.6}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Maximum Exact Property Fail", fn() {
        let errors =
          schema.validate("123.5", "{\"type\":\"number\", \"maximum\":123.4}")
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          NumberValue("maximum", None, Some(123.4)),
        )
        |> expect.to_be_true
      }),
      it("Basic Number Exclusive Maximum Property Fail", fn() {
        let errors =
          schema.validate(
            "123.5",
            "{\"type\":\"number\", \"exclusiveMaximum\":123.5}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          NumberValue("exclusiveMaximum", None, Some(123.5)),
        )
        |> expect.to_be_true
      }),
    ]),
    describe("Basic Number Multiples", [
      it("Basic Number Multiple Property", fn() {
        schema.validate("125", "{\"type\":\"number\", \"multipleOf\":25}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Multiple Float Property", fn() {
        schema.validate("125", "{\"type\":\"number\", \"multipleOf\":6.25}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Number Multiple Property Fails", fn() {
        let errors =
          schema.validate("125", "{\"type\":\"number\", \"multipleOf\":20}")
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          NumberValue("multipleOf", Some(20), None),
        )
        |> expect.to_be_true
      }),
      it("Basic Float Multiple Property", fn() {
        schema.validate("10.8", "{\"type\":\"number\", \"multipleOf\":3.6}")
        |> expect.to_equal(Ok(True))
      }),
    ]),
  ])
}

pub fn schema_array_tests() {
  describe("Schema Array Tests", [
    describe("Basic Arrays", [
      it("Basic Array Match", fn() {
        schema.validate("[]", "{\"type\":\"array\"}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Array Fail", fn() {
        let errors =
          schema.validate("\"123\"", "{\"type\":\"array\"}")
          |> expect.to_be_error
        contains_invalid_data_type_error(errors) |> expect.to_be_true
      }),
      describe("Arrays Item Numbers", [
        it("Basic Min Match", fn() {
          schema.validate("[1,2]", "{\"type\":\"array\",\"minItems\":2}")
          |> expect.to_equal(Ok(True))
        }),
        it("Basic Max Match", fn() {
          schema.validate("[1,2]", "{\"type\":\"array\",\"maxItems\":2}")
          |> expect.to_equal(Ok(True))
        }),
        it("Basic Min/Max Match", fn() {
          schema.validate(
            "[1,2,3,4,5]",
            "{\"type\":\"array\",\"minItems\":2,\"maxItems\":5}",
          )
          |> expect.to_equal(Ok(True))
        }),
        it("Basic Min Fail", fn() {
          let errors =
            schema.validate("[1]", "{\"type\":\"array\",\"minItems\":2}")
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("minItems", 2))
          |> expect.to_be_true
        }),
        it("Basic Max Fail", fn() {
          let errors =
            schema.validate("[1,2,3]", "{\"type\":\"array\",\"maxItems\":2}")
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("maxItems", 2))
          |> expect.to_be_true
        }),
        it("Basic Min/Max Min Fail", fn() {
          let errors =
            schema.validate(
              "[1,2,3,4,5]",
              "{\"type\":\"array\",\"minItems\":6,\"maxItems\":10}",
            )
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("minItems", 6))
          |> expect.to_be_true
        }),
        it("Basic Min/Max Max Fail", fn() {
          let errors =
            schema.validate(
              "[1,2,3,4,5,6]",
              "{\"type\":\"array\",\"minItems\":2,\"maxItems\":5}",
            )
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("maxItems", 5))
          |> expect.to_be_true
        }),
        it("Basic Min/Max Same Match", fn() {
          schema.validate(
            "[1,2,3,4,5]",
            "{\"type\":\"array\",\"minItems\":5,\"maxItems\":5}",
          )
          |> expect.to_equal(Ok(True))
        }),
        it("Basic Min/Max Same Fail", fn() {
          let errors =
            schema.validate(
              "[1,2,3,4,5,6]",
              "{\"type\":\"array\",\"minItems\":5,\"maxItems\":5}",
            )
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("maxItems", 5))
          |> expect.to_be_true
        }),
        it("Basic Min/Max Same Fail 2", fn() {
          let errors =
            schema.validate(
              "[1,2,3,4]",
              "{\"type\":\"array\",\"minItems\":5,\"maxItems\":5}",
            )
            |> expect.to_be_error
          contains_failed_property_error(errors, IntValue("minItems", 5))
          |> expect.to_be_true
        }),
      ]),
    ]),
    describe("Arrays Item Uniqueness", [
      it("Empty Unique Match", fn() {
        schema.validate("[]", "{\"type\":\"array\",\"uniqueItems\":true}")
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Unique Match", fn() {
        schema.validate("[1,2]", "{\"type\":\"array\",\"uniqueItems\":true}")
        |> expect.to_equal(Ok(True))
      }),
      it("Unique Not Needed Match", fn() {
        schema.validate("[1,2]", "{\"type\":\"array\",\"uniqueItems\":false}")
        |> expect.to_equal(Ok(True))
      }),
      it("Unique Not Needed Match 2", fn() {
        schema.validate("[1,2,1]", "{\"type\":\"array\",\"uniqueItems\":false}")
        |> expect.to_equal(Ok(True))
      }),
      it("More Complicated Unique Match", fn() {
        schema.validate(
          "[[1,2,3],[3,2,1],{},false]",
          "{\"type\":\"array\",\"uniqueItems\":true}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Basic Unique Fail", fn() {
        let errors =
          schema.validate(
            "[1,2,1]",
            "{\"type\":\"array\",\"uniqueItems\":true}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("More Complicated Unique Fail", fn() {
        let errors =
          schema.validate(
            "[[],[],3]",
            "{\"type\":\"array\",\"uniqueItems\":true}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("Unique Fail", fn() {
        let errors =
          schema.validate(
            "[true,true,123]",
            "{\"type\":\"array\",\"uniqueItems\":true}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("Unique Fail 2", fn() {
        let errors =
          schema.validate(
            "[[1,2,3],2,[1,2,3]]",
            "{\"type\":\"array\",\"uniqueItems\":true}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("Unique Fail 3", fn() {
        let errors =
          schema.validate(
            "[{\"type\":\"array\",\"uniqueItems\":true},1,2,3,4,{\"type\":\"array\",\"uniqueItems\":true}]",
            "{\"type\":\"array\",\"uniqueItems\":true}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("Basic Unique with Min Match", fn() {
        schema.validate(
          "[1,2]",
          "{\"type\":\"array\",\"uniqueItems\":true, \"minItems\":2}",
        )
        |> expect.to_equal(Ok(True))
      }),
      it("Unique with Min Fail", fn() {
        let errors =
          schema.validate(
            "[{\"type\":\"array\",\"uniqueItems\":true},1,2,3,4,{\"type\":\"array\",\"uniqueItems\":true}]",
            "{\"type\":\"array\",\"uniqueItems\":true, \"minItems\":5}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
      }),
      it("Unique with Min, Both Fail", fn() {
        let errors =
          schema.validate(
            "[{\"type\":\"array\",\"uniqueItems\":true},1,2,3,4,{\"type\":\"array\",\"uniqueItems\":true}]",
            "{\"type\":\"array\",\"uniqueItems\":true, \"minItems\":8}",
          )
          |> expect.to_be_error
        contains_failed_property_error(
          errors,
          BooleanValue("uniqueItems", True),
        )
        |> expect.to_be_true
        contains_failed_property_error(errors, IntValue("minItems", 8))
        |> expect.to_be_true
      }),
    ]),
  ])
}

fn contains_invalid_data_type_error(errors: List(InvalidEntry)) -> Bool {
  let err =
    errors
    |> list.find(fn(err) {
      case err {
        InvalidDataType(_) -> True
        _ -> False
      }
    })
  case err {
    Ok(_) -> True
    _ -> False
  }
}

fn contains_enum_error(errors: List(InvalidEntry)) -> Bool {
  let err =
    errors
    |> list.find(fn(err) {
      case err {
        NotMatchEnum(_) -> True
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
  fail_prop: PropertyValue,
) -> Bool {
  let err =
    errors
    |> list.find(fn(err) {
      case err {
        FailedProperty(prop, _) -> {
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
