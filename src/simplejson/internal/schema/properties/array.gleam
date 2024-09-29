import gleam/dict.{type Dict}
import gleam/option.{type Option}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, InvalidDataType,
}
import simplejson/jsonvalue.{type JsonValue, JsonArray}

pub const array_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(ValidationProperty), InvalidEntry),
    fn(ValidationProperty) ->
      Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
  ),
) = []

pub fn validate_array(
  node: JsonValue,
  _properties: List(fn(JsonValue) -> Option(InvalidEntry)),
) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonArray(_, _l) -> {
      Ok(True)
    }
    _ -> Error([InvalidDataType(node)])
  }
}
