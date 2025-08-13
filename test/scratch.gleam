import gleam/bit_array
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import simplejson/internal/schema/properties/properties.{
  AnyProperty, EnumProperty, ListProperty, NeededProperty,
}
import simplejson/internal/schema/schema
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonNull, JsonString, NoMD,
}

pub fn main() {
  //   parser.parse(
  //     //"{  \"type\": \"FeatureCollection\",  \"features\": [    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Point\",        \"coordinates\": [4.483605784808901, 51.907188449679325]      }    },    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Polygon\",        \"coordinates\": [          [            [3.974369110811523 , 51.907355547778565],            [4.173944459020191 , 51.86237166892457 ],            [4.3808076710679416, 51.848867725914914],            [4.579822414365026 , 51.874487141880024],            [4.534413416598767 , 51.9495302480326  ],            [4.365110733567974 , 51.92360787140825 ],            [4.179550508127079 , 51.97336560819281 ],            [4.018096293847009 , 52.00236546429852 ],            [3.9424146309028174, 51.97681895676649 ],            [3.974369110811523 , 51.907355547778565]          ]        ]      }}]}",
  //     // "[123123e100000]",
  //     // "[1.2e2,1.2e3,1.2e4,1.32423e7, 123000e-2]",
  //     // "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //     // "[0.12e05, 123.123123e-5,123.123123e5]",
  //     // "[-0.000000000000000000000000000000000000000000000000000000000000000000000000000001]",

  //     // "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //     "[\"abc\", [true, \"zyx\"], {},{\"key1\":true,\"key2\":null},false, null]",
  //   )
  //   |> io.debug
  //   let assert Ok(json) =
  //     parser.parse(
  //       //"{  \"type\": \"FeatureCollection\",  \"features\": [    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Point\",        \"coordinates\": [4.483605784808901, 51.907188449679325]      }    },    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Polygon\",        \"coordinates\": [          [            [3.974369110811523 , 51.907355547778565],            [4.173944459020191 , 51.86237166892457 ],            [4.3808076710679416, 51.848867725914914],            [4.579822414365026 , 51.874487141880024],            [4.534413416598767 , 51.9495302480326  ],            [4.365110733567974 , 51.92360787140825 ],            [4.179550508127079 , 51.97336560819281 ],            [4.018096293847009 , 52.00236546429852 ],            [3.9424146309028174, 51.97681895676649 ],            [3.974369110811523 , 51.907355547778565]          ]        ]      }}]}",
  //       // "[123123e100000]",
  //       // "[1.2e2,1.2e3,1.2e4,1.32423e7, 123000e-2]",
  //       // "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //       // "[0.12e05, 123.123123e-5,123.123123e5]",
  //       // "[-0.000000000000000000000000000000000000000000000000000000000000000000000000000001]",

  //       // "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //       "[\"abc\", [true, \"zyx\"], {},{\"key1\":true,\"key2\":null},false, null, 12891e30, 761.129834234313423499e2]",
  //     )
  //     |> io.debug

  //   json
  //   |> stringify.to_string
  //   |> io.debug
  // ieee_float.parse("1.0e309")
  // |> io.debug
  // |> ieee_float.multiply(ieee_float.parse("1.0e109"))
  // |> io.debug
  //   parser.parse("[0.3ez]\n")
  //   parser.parse(
  //     "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //   )
  //   |> io.debug
  //   case
  //     parser.parse(
  //       simplifile.read(
  //         "./test/testfiles/i_structure_UTF-8_BOM_empty_object.json",
  //       )
  //       |> result.unwrap(""),
  //     )
  //   {
  //     Error(jsonvalue.UnexpectedCharacter(a, b, c)) -> {
  //       io.debug(string.byte_size(a))
  //       io.debug(string.to_graphemes(a))
  //       a |> string.to_utf_codepoints |> io.debug
  //       Nil
  //     }
  //     _ as b -> {
  //       io.debug(b)
  //       Nil
  //     }
  //   }
  //   simplifile.read("./test/testfiles/i_structure_UTF-8_BOM_empty_object.json")
  //   |> result.unwrap("")
  //   |> string.to_utf_codepoints
  //   |> io.debug
  //   simplifile.read("./test/testfiles/n_structure_open_array_object.json")
  //   |> result.unwrap("")
  //   |> parser.parse
  //   |> io.debug
  //   parser.parse("{\"key\": }") |> io.debug
  //   io.debug(string.length("{\"key\": }"))
  // schema.validate("{}", "{}")
  // |> io.debug
  // schema.validate("{}", "true")
  // |> io.debug
  // schema.validate("{}", "false")
  // |> io.debug
  // schema.validate("{{[[]}", "true")
  // |> io.debug
  // schema.validate("123", "{\"type\":\"string\"}")
  // |> io.debug
  // schema.validate("\"123\"", "{\"type\":\"string\",\"minLength\":2}")
  // |> io.debug
  // schema.validate("\"123\"", "{\"type\":\"string\",\"minLength\":4}")
  // |> io.debug
  // schema.validate(
  //   "\"12345\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7}",
  // )
  // |> io.debug
  // schema.validate(
  //   "\"12345678\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7}",
  // )
  // |> io.debug
  // schema.validate(
  //   "\"123-567\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7,\"pattern\":\"\\\\d+-\\\\d+\"}",
  // )
  // |> io.debug
  // schema.validate(
  //   "\"123567\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7,\"pattern\":\"\\\\d+-\\\\d+\"}",
  // )
  // |> io.debug
  // schema.validate("\"123567\"", "{\"type\":\"number\"}")
  // |> io.debug
  // schema.validate("123567", "{\"type\":\"number\"}")
  // |> io.debug
  // schema.validate("123567.3", "{\"type\":\"number\"}")
  // |> io.debug
  // schema.validate("123567.3", "{\"type\":\"integer\"}")
  // |> io.debug
  // schema.validate("50005", "{\"type\":\"number\",\"multipleOf\":5}")
  // |> io.debug
  // schema.validate("50006", "{\"type\":\"number\",\"multipleOf\":5}")
  // |> io.debug
  // schema.validate("5.5", "{\"type\":\"number\",\"multipleOf\":1.1}")
  // |> io.debug
  // schema.validate("5.6", "{\"type\":\"number\",\"multipleOf\":1.1}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"number\",\"multipleOf\":2.5}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"number\",\"minimum\":5}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"number\",\"minimum\":10}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"number\",\"exclusiveMinimum\":10}")
  // |> io.debug
  // schema.validate("10.00001", "{\"type\":\"number\",\"exclusiveMinimum\":10}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"number\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("10", "{\"type\":\"boolean\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("true", "{\"type\":\"boolean\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("true", "{\"type\":\"null\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("null", "{\"type\":\"null\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("null", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  // |> io.debug
  // schema.validate("true", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  // |> io.debug
  // schema.validate("123", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  // |> io.debug
  // schema.validate("null", "{\"type\":\"array\",\"minimum\":15}")
  // |> io.debug
  // schema.validate("[]", "{\"type\":\"array\",\"minimum\":15}")
  // |> io.debug
  // schema.validate(
  //   "[1,2,   4]",
  //   "{\"type\":\"array\",\"items\":{\"type\":\"number\"},\"minimum\":15}",
  // )
  // |> io.debug
  // io.println(
  //   "{\"type\":\"string\", \"pattern\":\"\\\\d\\\\d\\\\d-\\\\d\\\\d\\\\d\"}",
  // )
  // schema.validate(
  //   "24",
  //   "{\"enum\":[2,4,6,24],\"type\":\"number\",\"multipleOf\":2}",
  // )
  // |> io.debug

  //\"prefixItems\":[{\"type\":\"number\"},{\"type\":\"number\"}],\"items\":true}",
  // schema.validate(
  //   "{\"a\":[{},1,false,1]}",
  //   "{\"type\":\"array\",\"minItems\":5, \"uniqueItems\":true}",
  // )
  // schema.validate(
  //   "[1,8, 2]",
  //   "{\"type\":\"array\",\"minItems\":3,\"items\":{\"type\":\"number\"}, \"contains\":{\"type\":\"boolean\"}}",
  // )
  // |> echo
  // simplejson.parse("{\"a\": []}")
  // |> echo

  list.each(schema.properties, fn(prop) {
    case
      schema.decode_property(
        prop,
        dict.from_list([#("type", JsonString(NoMD, "string"))]),
        // dict.from_list([
      //   #(
      //     "type",
      //     JsonArray(NoMD, [
      //       JsonString(NoMD, "array"),
      //       JsonString(NoMD, "number"),
      //     ]),
      //   ),
      // ]),
      )
      |> echo
    {
      Error(_) -> Nil

      Ok(Some(f)) -> {
        // f(JsonArray(NoMD, []))
        // f(JsonNull(NoMD))
        f(JsonString(NoMD, "Test"))
        |> echo
        Nil
      }

      Ok(None) -> Nil
    }
  })
}
