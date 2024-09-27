import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/properties/properties.{get_object_property}
import simplejson/internal/schema/types.{
  type InvalidEntry, type ValidationProperty, FailedProperty, InvalidSchema,
  NumberProperty,
}
import simplejson/jsonvalue.{type JsonValue}

pub const array_properties = [#("contains")]

fn array_items(
  value: ValidationProperty,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  todo
}
