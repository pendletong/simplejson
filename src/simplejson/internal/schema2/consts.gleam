import gleam/dict
import gleam/list
import gleam/option.{None}
import simplejson/internal/schema2/properties/array
import simplejson/internal/schema2/properties/number
import simplejson/internal/schema2/properties/object
import simplejson/internal/schema2/properties/string
import simplejson/internal/schema2/types.{
  type Context, type Property, type SchemaError, InvalidType, Property,
}

import simplejson/jsonvalue.{type JsonValue, JsonArray}

pub const schema_property = Property("$schema", types.String, types.ok_fn, None)

pub const defs_property = Property(
  "$defs",
  types.Object(types.Types([types.Boolean, types.Object(types.AnyType)])),
  types.ok_fn,
  None,
)

pub const type_property = Property(
  "type",
  types.Types([types.String, types.Array(types.String)]),
  types.valid_type_fn,
  None,
)

pub const enum_property = Property(
  "enum",
  types.Array(types.AnyType),
  enum_value_check,
  None,
)

pub const const_property = Property("const", types.AnyType, types.ok_fn, None)

pub const not_property = Property(
  "not",
  types.Types([types.Object(types.AnyType), types.Boolean]),
  types.ok_fn,
  None,
)

pub const items_property = Property(
  "items",
  types.Types([types.Object(types.AnyType), types.Boolean]),
  types.ok_fn,
  None,
)

pub const contains_property = Property(
  "contains",
  types.Types([types.Object(types.AnyType), types.Boolean]),
  types.ok_fn,
  None,
)

pub const properties_property = Property(
  "properties",
  types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
  types.ok_fn,
  None,
)

pub const pattern_properties_property = Property(
  "patternProperties",
  types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
  types.ok_fn,
  None,
)

pub const validator_list_property = Property(
  "prop_name",
  types.Array(types.Types([types.Object(types.AnyType), types.Boolean])),
  validator_list,
  None,
)

fn validator_list(
  v: JsonValue,
  c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    JsonArray(d, _) ->
      case dict.is_empty(d) {
        True -> Error(types.InvalidProperty(p.name, c.current_node))
        False -> Ok(True)
      }
    _ -> Error(types.InvalidProperty(p.name, c.current_node))
  }
}

fn enum_value_check(
  v: JsonValue,
  c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    JsonArray(d, _) -> {
      case dict.is_empty(d) {
        True -> Error(InvalidType(c.current_node, p))
        False -> {
          case
            { d |> dict.values |> list.unique |> list.length } == dict.size(d)
          {
            True -> Ok(True)
            False -> Error(InvalidType(c.current_node, p))
          }
        }
      }
    }
    _ -> Error(InvalidType(c.current_node, p))
  }
}

const type_checks = [
  #("number", number.num_properties, types.Number),
  #("integer", number.num_properties, types.Integer),
  #("string", string.string_properties, types.String),
  #("object", object.object_properties, types.Object(types.AnyType)),
  #("array", array.array_properties, types.Array(types.AnyType)),
  #("null", [], types.Null),
  #("boolean", [], types.Boolean),
]

pub fn get_checks(datatype: String) {
  case
    list.find(type_checks, fn(tc) {
      case tc {
        #(t, _, _) if t == datatype -> True
        _ -> False
      }
    })
  {
    Error(_) -> Error(types.SchemaError)
    Ok(#(_, checks, t)) -> Ok(#(t, checks))
  }
}

pub fn get_all_checks() {
  list.filter_map(type_checks, fn(tc) {
    let #(type_name, _, _) = tc
    // Filter out integer checks as these will be covered
    // under the number check
    case type_name {
      _ if type_name == "integer" -> Error(Nil)
      _ -> Ok(type_name)
    }
  })
}
