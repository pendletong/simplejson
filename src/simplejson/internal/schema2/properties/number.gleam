import simplejson/internal/schema2/types.{
  type Value, Number, NumberValue, Property, SchemaError, ok_fn,
}
import simplejson/jsonvalue

pub const num_properties = [#(Property("minimum", Number, ok_fn), minimum)]

fn minimum(
  v: Value,
) -> Result(
  fn(jsonvalue.JsonValue) -> Result(Nil, types.SchemaError),
  types.SchemaError,
) {
  case v {
    NumberValue(_, value:, or_value:) -> {
      Ok(fn(v) { todo })
    }
    _ -> Error(SchemaError)
  }
}
