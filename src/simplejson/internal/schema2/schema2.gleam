import gleam/bool
import gleam/dict
import gleam/function
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
  type Property, type Schema, type SchemaError, type ValidationInfo,
  type ValidationNode, type Value, Array, ArraySubValidation, ArrayValue,
  InvalidJson, InvalidType, MultipleValidation, NoType, Object, Property, Schema,
  SchemaError, SimpleValidation, StringValue, TypeValidation, Validation,
}

import simplejson/internal/utils.{unwrap_option_result}
import simplejson/jsonvalue.{type JsonValue, JsonBool, JsonObject}

const type_checks = [
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

type Context {
  Context(current_node: JsonValue, root_node: JsonValue)
}

pub fn get_validator_from_json(
  schema_json: JsonValue,
) -> Result(Schema, SchemaError) {
  use schema_uri <- result.try(get_property(
    schema_json,
    Property("$schema", types.String, types.ok_fn),
    // This needs to be fixed to validate uris
  ))
  case generate_validator(Context(schema_json, schema_json)) {
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
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  case context.current_node {
    jsonvalue.JsonBool(b, _) -> {
      Ok(SimpleValidation(b))
    }
    JsonObject(d, _) -> {
      case dict.is_empty(d) {
        True -> Ok(SimpleValidation(True))
        _ -> {
          generate_root_validation(context)
        }
      }
    }
    _ -> Error(SchemaError)
  }
}

fn generate_root_validation(
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  use <- bool.guard(
    when: !utils.is_object(context.current_node),
    return: Error(SchemaError),
  )
  let type_prop =
    Property(
      "type",
      types.Types([types.String, types.Array(types.String)]),
      types.valid_type_fn,
    )
  use instance_type <- result.try(get_property(context.current_node, type_prop))

  use enum <- result.try(get_property(
    context.current_node,
    Property("enum", Array(types.AnyType), fn(v, p) {
      case v {
        ArrayValue(_, value:) -> {
          case value {
            [] -> Error(InvalidType(context.current_node, p))
            _ -> {
              case { list.unique(value) |> list.length } == list.length(value) {
                True -> Ok(True)
                False -> Error(InvalidType(context.current_node, p))
              }
            }
          }
        }
        _ -> Error(InvalidType(context.current_node, p))
      }
    }),
  ))

  use const_val <- result.try(get_property(
    context.current_node,
    Property("const", types.AnyType, types.ok_fn),
  ))

  case instance_type {
    None -> {
      generate_multi_type_validation(context)
    }
    Some(StringValue(_, t)) -> {
      use validation <- result.try(get_validation_for_type(context, t))
      Ok(validation)
    }
    Some(ArrayValue(_, value:)) -> {
      use <- bool.guard(when: value == [], return: Ok(TypeValidation(NoType)))
      let types =
        list.map(value, fn(t) {
          let assert jsonvalue.JsonString(t, _) = t
          t
        })

      use <- bool.guard(
        when: types != list.unique(types),
        return: Error(types.InvalidProperty("type", context.current_node)),
      )

      use validations <- result.try(
        list.try_map(types, fn(t) { get_validation_for_type(context, t) }),
      )
      Ok(MultipleValidation(validations, types.Any, function.identity))
    }
    _ -> todo
  }
}

fn generate_multi_type_validation(context: Context) {
  use l <- result.try(
    list.map(type_checks, fn(tc) {
      let assert #(StringValue(_, t), _, _) = tc
      t
    })
    |> list.filter(fn(t) {
      // Filter out integer checks as these will be covered
      // under the number check
      t != "integer"
    })
    |> list.try_map(fn(t) { get_validation_for_type(context, t) }),
  )
  case
    list.find(l, fn(validation) {
      case validation {
        MultipleValidation([TypeValidation(_), ..], _, _) -> {
          True
        }
        _ -> False
      }
    })
  {
    Ok(_) ->
      Ok(MultipleValidation(l, types.Any, filter_validation_to_non_type_errors))
    Error(_) -> Ok(SimpleValidation(True))
  }
}

fn get_validation_for_type(
  context: Context,
  t: String,
) -> Result(types.ValidationNode, SchemaError) {
  use #(type_check, checks) <- result.try(get_checks(t))
  use validations <- result.try(
    list.try_fold(checks, [], fn(l, v) {
      let #(prop, v) = v
      case get_property(context.current_node, prop) {
        Error(e) -> Error(e)
        Ok(Some(val)) -> {
          use validation_fn <- result.try(v(val))
          Ok([Some(Validation(validation_fn)), ..l])
        }
        Ok(None) -> Ok(l)
      }
    }),
  )

  let main_validation = TypeValidation(type_check)

  use sub_validations <- result.try(case type_check {
    Array(_) -> {
      use subval <- result.try(get_array_subvalidation(context))
      Ok(subval)
    }
    Object(_) -> {
      use subval <- result.try(get_object_subvalidation(context))
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
    v -> types.MultipleValidation(v, types.All, function.identity)
  }
  |> Ok
}

fn filter_validation_to_non_type_errors(
  v: List(ValidationInfo),
) -> List(ValidationInfo) {
  list.filter(v, fn(vi) {
    case vi {
      types.IncorrectType(_, _) -> False
      _ -> True
    }
  })
}

fn get_array_subvalidation(
  context: Context,
) -> Result(Option(types.ValidationNode), SchemaError) {
  use prefix_items <- result.try(
    get_property(
      context.current_node,
      Property(
        "prefixItems",
        Array(types.Types([types.Object(types.AnyType), types.Boolean])),
        fn(v, p) {
          case v {
            ArrayValue(_, []) ->
              Error(types.InvalidProperty(p.name, context.current_node))
            ArrayValue(_, _) -> Ok(True)
            _ -> Error(types.InvalidProperty(p.name, context.current_node))
          }
        },
      ),
    )
    |> result.try(fn(v) {
      option.map(v, fn(pi) {
        case pi {
          ArrayValue(_, items) -> {
            list.try_map(items, fn(i) {
              generate_validator(Context(..context, current_node: i))
            })
          }
          _ -> Error(SchemaError)
        }
      })
      |> unwrap_option_result
    }),
  )
  use items <- result.try(
    get_property(
      context.current_node,
      Property(
        "items",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation(_, context))
      |> unwrap_option_result
    }),
  )
  use contains <- result.try(
    get_property(
      context.current_node,
      Property(
        "contains",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(v) {
      option.map(v, value_to_validation(_, context))
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
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  case v {
    types.ObjectValue(_, o) ->
      generate_validator(Context(..context, current_node: JsonObject(o, None)))
    types.BooleanValue(_, b) ->
      generate_validator(
        Context(..context, current_node: jsonvalue.JsonBool(b, None)),
      )
    _ -> Error(types.InvalidProperty(v.name, context.current_node))
  }
}

fn get_object_subvalidation(
  context: Context,
) -> Result(Option(types.ValidationNode), SchemaError) {
  let p =
    Property(
      "properties",
      types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
      types.ok_fn,
    )

  use properties <- result.try(
    get_property(context.current_node, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(types.ObjectValue(_, d)) -> {
          dict_to_validations(d, context, Ok)
        }
        Some(_) -> Error(InvalidType(context.current_node, p))
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
    get_property(context.current_node, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(types.ObjectValue(_, d)) -> {
          dict_to_validations(d, context, fn(k) {
            regexp.compile(k, regexp.Options(False, False))
            |> result.replace_error(InvalidType(context.current_node, p))
          })
        }
        Some(_) -> Error(InvalidType(context.current_node, p))
      }
    }),
  )

  use additional_properties <- result.try(
    get_property(
      context.current_node,
      Property(
        "additionalProperties",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation(_, context))
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
  context: Context,
  km: fn(String) -> Result(k, SchemaError),
) -> Result(Option(dict.Dict(k, ValidationNode)), SchemaError) {
  d
  |> dict.to_list
  |> list.try_map(fn(e) {
    case e {
      #(k, JsonObject(_, _) as jv) | #(k, JsonBool(_, _) as jv) -> {
        use k <- result.try(km(k))
        generate_validator(Context(..context, current_node: jv))
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
