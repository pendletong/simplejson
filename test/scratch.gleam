import simplejson
import simplejson/internal/schema/schema
import simplejson/internal/schema/validator

pub fn main() {
  let assert Ok(schema) =
    schema.get_validator("{\"type\":[\"null\",\"string\"]}")
  schema.validation |> echo
  let assert Ok(json) = simplejson.parse("false")

  validator.validate(json, schema) |> echo
}
