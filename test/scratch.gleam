import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/validator2

pub fn main() {
  // let assert Ok(json) = simplejson.parse("6")
  // let assert Ok(schema) =
  //   schema2.get_validator(
  //     "{
  //         \"$schema\": \"https://json-schema.org/draft/2020-12/schema\",
  //         \"multipleOf\":2
  //     }",
  //   )
  // schema |> validator2.validate(json, _) |> echo

  let assert Ok(schema) = schema2.get_validator("{\"minimum\":5}")
  let assert Ok(json) = simplejson.parse("3")
  validator2.validate(json, schema)
}
