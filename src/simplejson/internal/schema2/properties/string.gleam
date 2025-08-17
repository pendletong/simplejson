import simplejson/internal/schema2/types.{
  type SchemaError, type ValidationInfo, type Value, NumberValue, SchemaError,
}
import simplejson/jsonvalue.{type JsonValue}

pub const string_properties = [
  #(types.Property("maxLength", types.Integer, types.gtzero_fn), max_length),
]

fn max_length(v: Value) -> Result(fn(JsonValue) -> ValidationInfo, SchemaError) {
  case v {
    NumberValue(_, value, _) -> {
      Ok(fn(jsonvalue: JsonValue) { todo })
    }
    _ -> Error(SchemaError)
  }
}
