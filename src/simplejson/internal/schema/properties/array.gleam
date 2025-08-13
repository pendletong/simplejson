import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/properties/properties.{get_object_property}
import simplejson/internal/schema/types.{
  type InvalidEntry, type Number, type ValidationProperty, FailedProperty,
  InvalidSchema, Number, NumberProperty,
}
import simplejson/jsonvalue.{type JsonValue}

pub const array_properties = []

fn array_items(
  value: ValidationProperty,
) -> Result(
  fn(List(JsonValue)) -> Option(fn(JsonValue) -> InvalidEntry),
  InvalidEntry,
) {
  todo
}
