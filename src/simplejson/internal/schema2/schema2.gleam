import gleam/bool
import gleam/dict
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import simplejson
import simplejson/internal/pointer
import simplejson/internal/schema2/properties/array
import simplejson/internal/schema2/properties/number
import simplejson/internal/schema2/properties/object
import simplejson/internal/schema2/properties/string
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, type ValidationNode, Array,
  ArraySubValidation, Context, InvalidJson, InvalidType, MultipleValidation,
  NoType, Object, Property, Schema, SchemaError, SimpleValidation,
  TypeValidation, Validation, ValidatorProperties,
}
import simplejson/internal/stringify

import simplejson/internal/utils.{unwrap_option_result}
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
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

fn get_checks(datatype: String) {
  case
    list.find(type_checks, fn(tc) {
      case tc {
        #(t, _, _) if t == datatype -> True
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

pub fn get_validator_from_json(
  schema_json: JsonValue,
) -> Result(Schema, SchemaError) {
  let schema_json = case schema_json {
    JsonBool(_, Some(_))
    | JsonObject(_, Some(_))
    | JsonArray(_, Some(_))
    | JsonNull(Some(_))
    | JsonNumber(_, _, Some(_))
    | JsonString(_, Some(_)) -> utils.strip_metadata(schema_json)
    _ -> schema_json
  }
  let context = Context(schema_json, schema_json, dict.new())
  use schema_uri <- result.try(get_property(
    context,
    Property("$schema", types.String, types.ok_fn, None),
    // This needs to be fixed to validate uris
  ))
  case generate_validator(context) {
    Ok(validator) ->
      Ok(Schema(
        schema_uri
          |> option.map(fn(v) {
            case v {
              JsonString(value, _) -> value
              _ -> ""
            }
          }),
        None,
        schema_json,
        dict.new(),
        validator,
      ))
    Error(err) -> Error(err)
  }
}

fn generate_validator(
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  case context.current_node {
    JsonBool(b, _) -> {
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

fn find_ref(context: Context, ref: String) -> Result(Context, SchemaError) {
  todo as { "No $ref - " <> ref }
  use current_node <- result.try(
    case ref {
      "#" <> _ -> pointer.jsonpointer(context.root_node, ref) |> echo
      _ -> todo as { "No $ref (" <> ref <> ")" }
    }
    |> result.replace_error(SchemaError),
  )
  Ok(Context(..context, current_node:))
}

fn generate_root_validation(
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  use d <- result.try(case context.current_node {
    JsonObject(d, _) -> Ok(d)
    _ -> Error(SchemaError)
  })
  use context <- result.try(case dict.get(d, "$ref") {
    Ok(JsonString(ref, _)) -> find_ref(context, ref)
    Ok(j) -> Error(types.InvalidProperty("$ref", j))
    Error(_) -> Ok(context)
  })

  use instance_type <- result.try(get_property(
    context,
    Property(
      "type",
      types.Types([types.String, types.Array(types.String)]),
      types.valid_type_fn,
      None,
    ),
  ))

  use enum <- result.try(get_property(
    context,
    Property(
      "enum",
      Array(types.AnyType),
      fn(v, _c, p) {
        case v {
          JsonArray(d, _) -> {
            case dict.is_empty(d) {
              True -> Error(InvalidType(context.current_node, p))
              False -> {
                case
                  { list.unique(dict.values(d)) |> list.length } == dict.size(d)
                {
                  True -> Ok(True)
                  False -> Error(InvalidType(context.current_node, p))
                }
              }
            }
          }
          _ -> Error(InvalidType(context.current_node, p))
        }
      },
      None,
    ),
  ))

  use const_val <- result.try(get_property(
    context,
    Property("const", types.AnyType, types.ok_fn, None),
  ))

  use type_validation <- result.try(construct_type_validation(
    context,
    instance_type,
  ))

  case
    [
      enum |> option.map(validate_enum),
      const_val |> option.map(validate_const),
      Some(type_validation),
    ]
    |> option.values
  {
    [v] -> Ok(v)
    [] -> Error(SchemaError)
    v -> Ok(MultipleValidation(v, types.All, function.identity, False))
  }
}

fn validate_enum(v: JsonValue) {
  case v {
    JsonArray(array, _) -> {
      MultipleValidation(
        list.map(dict.values(array), validate_const),
        types.Any,
        function.identity,
        False,
      )
    }
    _ -> panic as "Enum parse error"
  }
}

fn validate_const(v: JsonValue) {
  Validation(fn(jsonvalue, _, ann) {
    case compare_jsons(v, jsonvalue) {
      True -> #(types.Valid, ann)
      False -> #(types.InvalidComparison(v, "equal", jsonvalue), ann)
    }
  })
}

fn compare_jsons(v: JsonValue, json: JsonValue) -> Bool {
  case v, json {
    JsonNumber(Some(i), _, _), JsonNumber(Some(i2), _, _) -> i == i2
    JsonNumber(_, Some(f), _), JsonNumber(_, Some(f2), _) -> f == f2
    JsonNumber(Some(i), _, _), JsonNumber(_, Some(f2), _) ->
      int.to_float(i) == f2
    JsonNumber(_, Some(f), _), JsonNumber(Some(i2), _, _) ->
      f == int.to_float(i2)
    _, _ -> v == json
  }
}

fn construct_type_validation(
  context: Context,
  instance_type: Option(JsonValue),
) -> Result(ValidationNode, SchemaError) {
  case instance_type {
    None -> {
      generate_multi_type_validation(context)
    }
    Some(JsonString(t, _)) -> {
      use validation <- result.try(get_validation_for_type(context, t))
      Ok(TypeValidation(dict.from_list([validation])))
    }
    Some(JsonArray(d, _)) -> {
      use <- bool.guard(
        when: dict.is_empty(d),
        return: Ok(
          TypeValidation(dict.from_list([#(NoType, SimpleValidation(False))])),
        ),
      )
      let types =
        list.map(dict.values(d), fn(t) {
          let assert JsonString(t, _) = t
          t
        })

      use <- bool.guard(
        when: types != list.unique(types),
        return: Error(types.InvalidProperty("type", context.current_node)),
      )

      use validations <- result.try(
        list.try_map(types, fn(t) { get_validation_for_type(context, t) }),
      )
      Ok(TypeValidation(dict.from_list(validations)))
    }
    _ -> todo
  }
}

fn generate_multi_type_validation(
  context: Context,
) -> Result(ValidationNode, SchemaError) {
  use l <- result.try(
    list.filter_map(type_checks, fn(tc) {
      let #(type_name, _, _) = tc
      // Filter out integer checks as these will be covered
      // under the number check
      case type_name {
        _ if type_name == "integer" -> Error(Nil)
        _ -> Ok(type_name)
      }
    })
    |> list.try_map(fn(t) { get_validation_for_type(context, t) }),
  )
  Ok(TypeValidation(dict.from_list(l)))
}

fn get_validation_for_type(
  context: Context,
  t: String,
) -> Result(#(types.ValueType, types.ValidationNode), SchemaError) {
  use #(type_check, checks) <- result.try(get_checks(t))
  use validations <- result.try(
    list.try_fold(checks, [], fn(l, prop) {
      case get_property(context, prop) {
        Error(e) -> Error(e)
        Ok(Some(val)) -> {
          use validation_fn <- result.try(case prop {
            Property(_, _, _, Some(validator_fn)) -> {
              use vfn <- result.try(validator_fn(val))
              Ok(
                Some(
                  Validation(fn(json, _, annotation) { vfn(json, annotation) }),
                ),
              )
            }
            ValidatorProperties(_, _, _, Some(validator_fn)) -> {
              use vfn <- result.try(
                validator_fn(val, fn(json) {
                  generate_validator(Context(..context, current_node: json))
                }),
              )
              Ok(Some(Validation(vfn)))
            }
            _ -> Ok(None)
          })
          Ok([validation_fn, ..l])
        }
        Ok(None) -> Ok(l)
      }
    }),
  )

  use sub_validations <- result.try(case type_check {
    Array(_) -> {
      use subval <- result.try(get_array_subvalidation(context))
      Ok(subval)
    }
    Object(_) -> {
      use subval <- result.try(get_object_subvalidation(context))
      Ok(subval)
    }
    _ -> Ok([None])
  })

  use subschema <- result.try(get_subschemas(context))

  use then <- result.try(get_validation_property(context, "then"))
  use orelse <- result.try(get_validation_property(context, "else"))

  use if_validation <- result.try(get_validation_property(context, "if"))

  let ifthen = [
    case if_validation {
      Some(ifprop) -> Some(types.IfThenValidation(ifprop, then, orelse))
      None -> None
    },
  ]

  use unevaluated <- result.try(case type_check {
    Array(_) -> {
      get_unevaluated(context, "unevaluatedItems", array.unevaluated_items)
    }
    Object(_) -> {
      get_unevaluated(
        context,
        "unevaluatedProperties",
        object.unevaluated_properties,
      )
    }
    _ -> Ok([None])
  })

  #(
    type_check,
    case
      [
        sub_validations,
        validations,
        subschema,
        ifthen,
        unevaluated,
      ]
      |> list.flatten
      |> option.values
    {
      [] -> SimpleValidation(True)
      [v] -> v
      v -> types.MultipleValidation(v, types.All, function.identity, False)
    },
  )
  |> Ok
}

fn get_unevaluated(
  context: Context,
  prop: String,
  uneval_fn: fn(JsonValue, fn(JsonValue) -> Result(ValidationNode, SchemaError)) ->
    Result(
      fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
      SchemaError,
    ),
) -> Result(List(Option(ValidationNode)), SchemaError) {
  case
    get_property(
      context,
      ValidatorProperties(
        prop,
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
        Some(object.unevaluated_properties),
      ),
    )
  {
    Error(e) -> Error(e)
    Ok(Some(val)) -> {
      use validation_fn <- result.try({
        use vfn <- result.try(
          uneval_fn(val, fn(json) {
            generate_validator(Context(..context, current_node: json))
          }),
        )
        Ok(Some(Validation(vfn)))
      })
      Ok([validation_fn])
    }
    Ok(None) -> Ok([])
  }
}

fn get_subschemas(
  context: Context,
) -> Result(List(Option(ValidationNode)), SchemaError) {
  use all_of <- result.try(get_validator_list(context, "allOf"))
  let all_of =
    option.map(all_of, MultipleValidation(_, types.All, function.identity, True))

  use any_of <- result.try(get_validator_list(context, "anyOf"))
  let any_of =
    option.map(any_of, MultipleValidation(_, types.Any, function.identity, True))

  use one_of <- result.try(get_validator_list(context, "oneOf"))
  let one_of =
    option.map(one_of, MultipleValidation(_, types.One, function.identity, True))

  use not <- result.try(
    get_property(
      context,
      Property(
        "not",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
        None,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation("not", _, context))
      |> unwrap_option_result
    }),
  )
  let not = option.map(not, types.NotValidation)

  Ok([all_of, any_of, one_of, not])
}

fn get_array_subvalidation(
  context: Context,
) -> Result(List(Option(types.ValidationNode)), SchemaError) {
  use prefix_items <- result.try(get_validator_list(context, "prefixItems"))
  use items <- result.try(
    get_property(
      context,
      Property(
        "items",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
        None,
      ),
    )
    |> result.try(fn(i) {
      option.map(i, value_to_validation("items", _, context))
      |> unwrap_option_result
    }),
  )
  use contains <- result.try(
    get_property(
      context,
      Property(
        "contains",
        types.Types([types.Object(types.AnyType), types.Boolean]),
        types.ok_fn,
        None,
      ),
    )
    |> result.try(fn(v) {
      option.map(v, value_to_validation("contains", _, context))
      |> unwrap_option_result
    }),
  )
  // Add in a min contains of 1 if there is not actual minContains
  // property
  use min_contains <- result.try(case contains {
    Some(_) -> {
      case context.current_node {
        JsonObject(d, _) -> {
          case dict.has_key(d, "minContains") {
            True -> Ok(None)
            False -> {
              use min_fn <- result.try(array.get_min_contains(
                JsonNumber(Some(1), None, None),
                "contains",
              ))
              Ok(
                Some(
                  Validation(fn(json, _, annotation) {
                    min_fn(json, annotation)
                  }),
                ),
              )
            }
          }
        }
        _ -> Error(SchemaError)
      }
    }
    None -> Ok(None)
  })
  case
    option.is_some(prefix_items)
    || option.is_some(items)
    || option.is_some(contains)
  {
    True ->
      Ok([Some(ArraySubValidation(prefix_items, items, contains)), min_contains])
    False -> Ok([None])
  }
}

fn get_validator_list(context: Context, prop_name: String) {
  get_property(
    context,
    Property(
      prop_name,
      Array(types.Types([types.Object(types.AnyType), types.Boolean])),
      fn(v, _c, p) {
        case v {
          JsonArray(d, _) ->
            case dict.is_empty(d) {
              True -> Error(types.InvalidProperty(p.name, context.current_node))
              False -> Ok(True)
            }
          _ -> Error(types.InvalidProperty(p.name, context.current_node))
        }
      },
      None,
    ),
  )
  |> result.try(fn(v) {
    option.map(v, fn(pi) {
      case pi {
        JsonArray(items, _) -> {
          list.try_map(stringify.dict_to_ordered_list(items), fn(i) {
            generate_validator(Context(..context, current_node: i))
          })
        }
        _ -> Error(SchemaError)
      }
    })
    |> unwrap_option_result
  })
}

fn value_to_validation(
  prop_name: String,
  v: JsonValue,
  context: Context,
) -> Result(types.ValidationNode, SchemaError) {
  case v {
    JsonObject(o, _) ->
      generate_validator(Context(..context, current_node: JsonObject(o, None)))
    JsonBool(b, _) ->
      generate_validator(Context(..context, current_node: JsonBool(b, None)))
    _ -> Error(types.InvalidProperty(prop_name, context.current_node))
  }
}

fn get_object_subvalidation(
  context: Context,
) -> Result(List(Option(types.ValidationNode)), SchemaError) {
  let p =
    Property(
      "properties",
      types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
      types.ok_fn,
      None,
    )

  use properties <- result.try(
    get_property(context, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(JsonObject(d, _)) -> {
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
      None,
    )

  use pattern_properties <- result.try(
    get_property(context, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(None)
        Some(JsonObject(d, _)) -> {
          dict_to_validations(d, context, fn(k) {
            regexp.compile(k, regexp.Options(False, False))
            |> result.replace_error(InvalidType(context.current_node, p))
          })
          |> result.map(option.map(_, dict.to_list))
        }
        Some(_) -> Error(InvalidType(context.current_node, p))
      }
    }),
  )

  use additional_properties <- result.try(get_validation_property(
    context,
    "additionalProperties",
  ))
  case
    option.is_some(properties)
    || option.is_some(additional_properties)
    || option.is_some(pattern_properties)
  {
    True ->
      Ok([
        Some(types.ObjectSubValidation(
          properties,
          pattern_properties,
          additional_properties,
        )),
      ])
    False -> Ok([None])
  }
}

fn get_validation_property(context: Context, prop_name: String) {
  get_property(
    context,
    Property(
      prop_name,
      types.Types([types.Object(types.AnyType), types.Boolean]),
      types.ok_fn,
      None,
    ),
  )
  |> result.try(fn(i) {
    option.map(i, value_to_validation(prop_name, _, context))
    |> unwrap_option_result
  })
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
  context: Context,
  property: Property,
) -> Result(Option(JsonValue), SchemaError) {
  case context.current_node {
    JsonObject(d, _) -> {
      case dict.get(d, property.name) {
        Error(_) -> Ok(None)
        Ok(val) -> {
          use t <- result.try(types.validate_type(val, context, property))
          Ok(t)
        }
      }
    }
    _ -> Ok(None)
  }
}
