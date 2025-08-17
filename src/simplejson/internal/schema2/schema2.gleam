import gleam/bool
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import simplejson
import simplejson/internal/schema2/properties/array
import simplejson/internal/schema2/properties/number
import simplejson/internal/schema2/properties/object
import simplejson/internal/schema2/properties/string
import simplejson/internal/schema2/types.{
  type Property, type Schema, type SchemaError, type ValidationNode, type Value,
  Array, ArraySubValidation, ArrayValue, InvalidJson, InvalidType,
  MultipleValidation, Object, Property, Schema, SchemaError, SimpleValidation,
  StringValue, Validation,
}

import simplejson/internal/utils.{unwrap_option_result}
import simplejson/jsonvalue.{type JsonValue, JsonBool, JsonObject}

pub const type_checks = [
  #(StringValue("", "number"), number.num_properties, types.Number),
  #(StringValue("", "integer"), number.num_properties, types.Integer),
  #(StringValue("", "string"), string.string_properties, types.String),
  #(
    StringValue("", "object"),
    object.object_properties,
    types.Object(types.AnyType),
  ),
  #(
    StringValue("", "array"),
    array.array_properties,
    types.Array(types.AnyType),
  ),
  #(StringValue("", "null"), [], types.Null),
  #(StringValue("", "boolean"), [], types.Boolean),
]

fn get_checks(datatype: String) {
  case
    list.find(type_checks, fn(tc) {
      case tc {
        #(StringValue(_, t), _, _) if t == datatype -> True
        _ -> False
      }
    })
  {
    Error(_) -> Error(SchemaError)
    Ok(#(_, checks, t)) -> Ok(#(t, checks))
  }
}

pub fn get_validator(schema: String) -> Result(Schema, SchemaError) {
  use schema <- result.try(
    simplejson.parse(schema) |> result.replace_error(InvalidJson),
  )
  get_validator_from_json(schema)
}

fn get_validator_from_json(
  schema_json: JsonValue,
) -> Result(Schema, SchemaError) {
  use schema_uri <- result.try(get_property(
    schema_json,
    Property("$schema", types.String, types.ok_fn),
    // This needs to be fixed to validate uris
  ))
  case generate_validator(schema_json, schema_json) {
    Ok(validator) ->
      Ok(Schema(
        schema_uri
          |> option.map(fn(v) {
            case v {
              types.StringValue(_, value) -> value
              _ -> ""
            }
          }),
        None,
        schema_json,
        validator,
      ))
    Error(err) -> Error(err)
  }
}

fn generate_validator(
  schema_json: JsonValue,
  schema_root: JsonValue,
) -> Result(types.ValidationNode, SchemaError) {
  case schema_json {
    jsonvalue.JsonBool(b, _) -> {
      Ok(SimpleValidation(b))
    }
    JsonObject(d, _) -> {
      case dict.is_empty(d) {
        True -> Ok(SimpleValidation(True))
        _ -> {
          generate_root_validation(schema_json, schema_root)
        }
      }
    }
    _ -> Error(SchemaError)
  }
}

fn generate_root_validation(
  schema_json: JsonValue,
  schema_root: JsonValue,
) -> Result(types.ValidationNode, SchemaError) {
  use <- bool.guard(
    when: !utils.is_object(schema_json),
    return: Error(SchemaError),
  )
  use instance_type <- result.try(get_property(
    schema_json,
    Property(
      "type",
      types.Types([types.String, types.Array(types.String)]),
      types.valid_type_fn,
    ),
  ))

  use enum <- result.try(get_property(
    schema_json,
    Property("enum", Array(types.AnyType), fn(v, p) {
      case v {
        ArrayValue(_, value:) -> {
          case value {
            [] -> Error(InvalidType(schema_json, p))
            _ -> {
              case { list.unique(value) |> list.length } == list.length(value) {
                True -> Ok(True)
                False -> Error(InvalidType(schema_json, p))
              }
            }
          }
        }
        _ -> Error(InvalidType(schema_json, p))
      }
    }),
  ))

  use const_val <- result.try(get_property(
    schema_json,
    Property("const", types.AnyType, types.ok_fn),
  ))

  case instance_type {
    None -> {
      todo
      // Generate multinode for all datatypes
    }
    Some(StringValue(_, t)) -> {
      use validation <- result.try(get_validation_for_type(
        schema_json,
        schema_root,
        t,
      ))
      Ok(validation)
    }
    Some(ArrayValue(_, value:)) -> {
      use l <- result.try(
        list.try_map(value, fn(t) {
          let assert jsonvalue.JsonString(t, _) = t
          get_validation_for_type(schema_json, schema_json, t)
        }),
      )
      Ok(MultipleValidation(l, types.Any))
    }
    _ -> todo
  }
}

fn get_validation_for_type(
  schema_json: JsonValue,
  schema_root: JsonValue,
  t: String,
) -> Result(types.ValidationNode, SchemaError) {
  use #(type_check, checks) <- result.try(get_checks(t))
  use validations <- result.try(
    list.try_fold(checks, [], fn(l, v) {
      let #(prop, v) = v
      case get_property(schema_json, prop) {
        Error(e) -> Error(e)
        Ok(Some(val)) -> {
          use validation_fn <- result.try(v(val))
          Ok([Some(Validation(validation_fn)), ..l])
        }
        Ok(None) -> Ok(l)
      }
    }),
  )

  let main_validation = types.TypeValidation(type_check)

  use sub_validations <- result.try(case type_check {
    Array(_) -> {
      use subval <- result.try(get_array_subvalidation(schema_json, schema_root))
      Ok(subval)
    }
    Object(_) -> {
      use subval <- result.try(get_object_subvalidation(
        schema_json,
        schema_root,
      ))
      Ok(subval)
    }
    _ -> Ok(None)
  })

  case
    [[main_validation |> Some], [sub_validations], validations]
    |> list.flatten
    |> option.values
  {
    [v] -> v
    v -> types.MultipleValidation(v, types.All)
  }
  |> Ok
}

fn get_array_subvalidation(
  schema_json: JsonValue,
  schema_root: JsonValue,
) -> Result(Option(types.ValidationNode), SchemaError) {
  use prefix_items <- result.try(
    get_property(
      schema_json,
      Property(
        "prefixItems",
        Array(types.Types([types.Object(types.AnyType), types.Boolean])),
        fn(v, p) {
          case v {
            ArrayValue(_, []) ->
              Error(types.InvalidProperty(p.name, schema_json))
            ArrayValue(_, _) -> Ok(True)
            _ -> Error(types.InvalidProperty(p.name, schema_json))
          }
        },
      ),
    )
    |> result.try(fn(v) {
      option.map(v, fn(pi) {
        case pi {
          ArrayValue(_, items) -> {
            list.try_map(items, fn(i) { generate_validator(i, schema_root) })
          }
          _ -> Error(SchemaError)
        }
      })
      |> unwrap_option_result
    }),
  )
  use items <- result.try(
    get_property(
      schema_json,
      Property(
        "items",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation(_, schema_json, schema_root))
      |> unwrap_option_result
    }),
  )
  use contains <- result.try(
    get_property(
      schema_json,
      Property(
        "contains",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(v) {
      option.map(v, value_to_validation(_, schema_json, schema_root))
      |> unwrap_option_result
    }),
  )
  case
    option.is_some(prefix_items)
    || option.is_some(items)
    || option.is_some(contains)
  {
    True -> Ok(Some(ArraySubValidation(prefix_items, items, contains)))
    False -> Ok(None)
  }
}

fn value_to_validation(
  v: Value,
  schema_json: JsonValue,
  schema_root: JsonValue,
) -> Result(types.ValidationNode, SchemaError) {
  case v {
    types.ObjectValue(_, o) ->
      generate_validator(JsonObject(o, None), schema_root)
    types.BooleanValue(_, b) ->
      generate_validator(jsonvalue.JsonBool(b, None), schema_root)
    _ -> Error(types.InvalidProperty(v.name, schema_json))
  }
}

fn get_object_subvalidation(
  schema_json: JsonValue,
  schema_root: JsonValue,
) -> Result(Option(types.ValidationNode), SchemaError) {
  let p =
    Property(
      "properties",
      types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
      types.ok_fn,
    )

  use properties <- result.try(
    get_property(schema_json, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(types.ObjectValue(_, d)) -> {
          dict_to_validations(d, schema_root, Ok)
        }
        Some(_) -> Error(InvalidType(schema_json, p))
      }
    }),
  )

  let p =
    Property(
      "patternProperties",
      types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
      types.ok_fn,
    )

  use pattern_properties <- result.try(
    get_property(schema_json, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(types.ObjectValue(_, d)) -> {
          dict_to_validations(d, schema_root, fn(k) {
            regexp.compile(k, regexp.Options(False, False))
            |> result.replace_error(InvalidType(schema_json, p))
          })
        }
        Some(_) -> Error(InvalidType(schema_json, p))
      }
    }),
  )

  use additional_properties <- result.try(
    get_property(
      schema_json,
      Property(
        "additionalProperties",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation(_, schema_json, schema_root))
      |> unwrap_option_result
    }),
  )
  case
    option.is_some(properties)
    || option.is_some(additional_properties)
    || option.is_some(pattern_properties)
  {
    True ->
      Ok(
        Some(types.ObjectSubValidation(
          properties,
          pattern_properties,
          additional_properties,
        )),
      )
    False -> Ok(None)
  }
}

fn dict_to_validations(
  d: dict.Dict(String, JsonValue),
  schema_root: JsonValue,
  km: fn(String) -> Result(k, SchemaError),
) -> Result(Option(dict.Dict(k, ValidationNode)), SchemaError) {
  d
  |> dict.to_list
  |> list.try_map(fn(e) {
    case e {
      #(k, JsonObject(_, _) as jv) | #(k, JsonBool(_, _) as jv) -> {
        use k <- result.try(km(k))
        generate_validator(jv, schema_root)
        |> result.map(fn(v) { #(k, v) })
      }
      _ -> Error(SchemaError)
    }
  })
  |> result.map(fn(l) { Some(dict.from_list(l)) })
}

fn get_property(
  json: JsonValue,
  property: Property,
) -> Result(Option(Value), SchemaError) {
  case json {
    JsonObject(d, _) -> {
      case dict.get(d, property.name) {
        Error(_) -> Ok(None)
        Ok(val) -> {
          use t <- result.try(types.validate_type(val, property))
          Ok(t)
        }
      }
    }
    _ -> Ok(None)
  }
}

fn map_to_value(json: JsonValue) -> Value {
  todo
}
