import gleam/dict.{type Dict}
import gleam/option.{type Option}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty,
}

import simplejson/jsonvalue.{type JsonValue}

pub const array_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(ValidationProperty), InvalidEntry),
    fn(ValidationProperty) ->
      Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
  ),
) = []
