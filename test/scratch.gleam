import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/validator2

pub fn main() {
  let assert Ok(schema) =
    schema2.get_validator("{\"type\":[\"null\",\"string\"]}")
  schema.validation |> echo
  let assert Ok(json) = simplejson.parse("false")

  validator2.validate(json, schema) |> echo
}
