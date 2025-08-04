import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplejson/internal/parser
import simplejson/internal/schema/schema
import simplejson/internal/stringify
import simplejson/jsonvalue
import simplifile

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
  //   |> echo
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
  //     |> echo

  //   json
  //   |> stringify.to_string
  //   |> echo
  // ieee_float.parse("1.0e309")
  // |> echo
  // |> ieee_float.multiply(ieee_float.parse("1.0e109"))
  // |> echo
  //   parser.parse("[0.3ez]\n")
  //   parser.parse(
  //     "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  //   )
  //   |> echo
  //   case
  //     parser.parse(
  //       simplifile.read(
  //         "./test/testfiles/i_structure_UTF-8_BOM_empty_object.json",
  //       )
  //       |> result.unwrap(""),
  //     )
  //   {
  //     Error(jsonvalue.UnexpectedCharacter(a, b, c)) -> {
  //       echo(string.byte_size(a))
  //       echo(string.to_graphemes(a))
  //       a |> string.to_utf_codepoints |> echo
  //       Nil
  //     }
  //     _ as b -> {
  //       echo(b)
  //       Nil
  //     }
  //   }
  //   simplifile.read("./test/testfiles/i_structure_UTF-8_BOM_empty_object.json")
  //   |> result.unwrap("")
  //   |> string.to_utf_codepoints
  //   |> echo
  //   simplifile.read("./test/testfiles/n_structure_open_array_object.json")
  //   |> result.unwrap("")
  //   |> parser.parse
  //   |> echo
  //   parser.parse("{\"key\": }") |> echo
  //   echo(string.length("{\"key\": }"))
  // schema.validate("{}", "{}")
  // |> echo
  // schema.validate("{}", "true")
  // |> echo
  // schema.validate("{}", "false")
  // |> echo
  // schema.validate("{{[[]}", "true")
  // |> echo
  // schema.validate("123", "{\"type\":\"string\"}")
  // |> echo
  // schema.validate("\"123\"", "{\"type\":\"string\",\"minLength\":2}")
  // |> echo
  // schema.validate("\"123\"", "{\"type\":\"string\",\"minLength\":4}")
  // |> echo
  // schema.validate(
  //   "\"12345\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7}",
  // )
  // |> echo
  // schema.validate(
  //   "\"12345678\"",
  //   "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7}",
  // )
  // |> echo
  schema.validate(
    "\"123-567\"",
    "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7,\"pattern\":\"\\\\d+-\\\\d+\"}",
  )
  |> echo
  schema.validate(
    "\"123567\"",
    "{\"type\":\"string\",\"minLength\":4, \"maxLength\":7,\"pattern\":\"\\\\d+-\\\\d+\"}",
  )
  |> echo
  schema.validate("\"123567\"", "{\"type\":\"number\"}")
  |> echo
  schema.validate("123567", "{\"type\":\"number\"}")
  |> echo
  schema.validate("123567.3", "{\"type\":\"number\"}")
  |> echo
  schema.validate("123567.3", "{\"type\":\"integer\"}")
  |> echo
  schema.validate("50005", "{\"type\":\"number\",\"multipleOf\":5}")
  |> echo
  schema.validate("50006", "{\"type\":\"number\",\"multipleOf\":5}")
  |> echo
  schema.validate("5.5", "{\"type\":\"number\",\"multipleOf\":1.1}")
  |> echo
  schema.validate("5.6", "{\"type\":\"number\",\"multipleOf\":1.1}")
  |> echo
  schema.validate("10", "{\"type\":\"number\",\"multipleOf\":2.5}")
  |> echo
  schema.validate("10", "{\"type\":\"number\",\"minimum\":5}")
  |> echo
  schema.validate("10", "{\"type\":\"number\",\"minimum\":10}")
  |> echo
  schema.validate("10", "{\"type\":\"number\",\"exclusiveMinimum\":10}")
  |> echo
  schema.validate("10.00001", "{\"type\":\"number\",\"exclusiveMinimum\":10}")
  |> echo
  schema.validate("10", "{\"type\":\"number\",\"minimum\":15}")
  |> echo
  schema.validate("10", "{\"type\":\"boolean\",\"minimum\":15}")
  |> echo
  schema.validate("true", "{\"type\":\"boolean\",\"minimum\":15}")
  |> echo
  schema.validate("true", "{\"type\":\"null\",\"minimum\":15}")
  |> echo
  schema.validate("null", "{\"type\":\"null\",\"minimum\":15}")
  |> echo
  schema.validate("null", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  |> echo
  schema.validate("true", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  |> echo
  schema.validate("123", "{\"type\":[\"null\", \"boolean\"],\"minimum\":15}")
  |> echo
  schema.validate("null", "{\"type\":\"array\",\"minimum\":15}")
  |> echo
  schema.validate("[]", "{\"type\":\"array\",\"minimum\":15}")
  |> echo
  schema.validate(
    "[1,2,   4]",
    "{\"type\":\"array\",\"items\":{\"type\":\"number\"},\"minimum\":15}",
  )
  |> echo
  io.println(
    "{\"type\":\"string\", \"pattern\":\"\\\\d\\\\d\\\\d-\\\\d\\\\d\\\\d\"}",
  )
}
