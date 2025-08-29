import gleam/bool
import gleam/dict
import gleam/function
import gleam/int
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
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, type ValidationNode, ArraySubValidation,
  Context, FinishLevel, InvalidJson, InvalidType, MultipleValidation, NoType,
  Property, RefValidation, Schema, SchemaError, SimpleValidation, TypeValidation,
  Validation, ValidatorProperties,
}
import simplejson/internal/stringify

import simplejson/internal/utils.{
  construct_new_context, merge_context, unwrap_option_result,
}
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
  let context = Context(schema_json, None, schema_json, dict.new())
  use schema_uri <- result.try(get_property(
    context,
    Property("$schema", types.String, types.ok_fn, None),
    // This needs to be fixed to validate uris
  ))
  case generate_validator(context, schema_json) {
    Ok(new_context) ->
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
        new_context.schemas,
        option.unwrap(new_context.current_validator, SimpleValidation(True)),
      ))
    Error(err) -> Error(err)
  }
}

pub fn add_validator_to_context(
  context: Context,
  validator: ValidationNode,
) -> Context {
  let new_schemas = case context.current_node {
    JsonObject(_, _) ->
      dict.insert(context.schemas, context.current_node, Some(validator))
    _ -> context.schemas
  }
  Context(..context, current_validator: Some(validator), schemas: new_schemas)
}

fn generate_validator(
  context: Context,
  json: JsonValue,
) -> Result(Context, SchemaError) {
  case json {
    JsonBool(b, _) -> {
      Ok(add_validator_to_context(context, SimpleValidation(b)))
    }
    JsonObject(d, _) -> {
      case dict.is_empty(d) {
        True -> Ok(add_validator_to_context(context, SimpleValidation(True)))
        _ -> {
          generate_root_validation(Context(..context, current_node: json))
          |> utils.revert_current_node(context.current_node)
        }
      }
    }
    _ -> Error(SchemaError)
  }
}

fn generate_root_validation(context: Context) -> Result(Context, SchemaError) {
  use d <- result.try(case context.current_node {
    JsonObject(d, _) -> Ok(d)
    _ -> Error(SchemaError)
  })

  case dict.get(d, "$dynamicRef") {
    Ok(_) -> panic
    Error(_) -> Nil
  }

  use ref <- result.try(case dict.get(d, "$ref") {
    Ok(JsonString(ref, _)) -> Ok(Some(ref))
    Ok(j) -> Error(types.InvalidProperty("$ref", j))
    Error(_) -> Ok(None)
  })

  use defs <- result.try(get_property(
    context,
    Property(
      "$defs",
      types.Object(types.Types([types.Boolean, types.Object(types.AnyType)])),
      types.ok_fn,
      None,
    ),
  ))

  use context <- result.try(case defs {
    Some(JsonObject(d, _)) -> {
      use #(context, _) <- result.try(
        dict_to_validations(d, context, Ok)
        |> result.map(fn(e) {
          let #(context, properties) = e
          #(context, Some(properties))
        }),
      )
      Ok(context)
    }
    _ -> Ok(context)
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
      types.Array(types.AnyType),
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

  use context <- result.try(construct_type_validation(context, instance_type))

  case
    [
      ref |> option.map(RefValidation),
      enum |> option.map(validate_enum),
      const_val |> option.map(validate_const),
      context.current_validator,
      Some(FinishLevel),
    ]
    |> option.values
  {
    // [v, FinishLevel] -> Ok(add_validator_to_context(context, v))
    [FinishLevel] -> Error(SchemaError)
    v ->
      Ok(add_validator_to_context(
        context,
        MultipleValidation(v, types.All, function.identity, False),
      ))
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
) -> Result(Context, SchemaError) {
  case instance_type {
    None -> {
      generate_multi_type_validation(context)
    }
    Some(JsonString(t, _)) -> {
      use validator <- result.try(get_validation_for_type(context, t))
      apply_multiple_type_validations(context, [validator])
    }
    Some(JsonArray(d, _)) -> {
      use <- bool.guard(
        when: dict.is_empty(d),
        return: Ok(add_validator_to_context(
          context,
          TypeValidation(dict.from_list([#(NoType, SimpleValidation(False))])),
        )),
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
      apply_multiple_type_validations(context, validations)
    }
    _ -> todo
  }
}

fn apply_multiple_type_validations(
  context: Context,
  l: List(#(types.ValueType, Context)),
) -> Result(Context, SchemaError) {
  let context =
    list.fold(l, context, fn(context, val) {
      let #(_, val_context) = val
      merge_context(context, val_context)
    })
  use l <- result.try(
    list.try_map(l, fn(e) {
      let #(vt, context) = e
      case context.current_validator {
        Some(validator) -> Ok(#(vt, validator))
        None -> Error(SchemaError)
      }
    }),
  )
  Ok(add_validator_to_context(context, TypeValidation(dict.from_list(l))))
}

fn generate_multi_type_validation(
  context: Context,
) -> Result(Context, SchemaError) {
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
  apply_multiple_type_validations(context, l)
}

fn apply_property(
  prop: Property,
  context: Context,
  json: JsonValue,
  kind: fn(
    fn(JsonValue, Schema, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  ) ->
    ValidationNode,
) -> Result(#(Context, Option(ValidationNode)), SchemaError) {
  case prop {
    Property(_, _, _, Some(validator_fn)) -> {
      use vfn <- result.try(validator_fn(json))
      Ok(#(
        context,
        Some(kind(fn(json, _, annotation) { vfn(json, annotation) })),
      ))
    }
    ValidatorProperties(_, _, _, Some(validator_fn)) -> {
      use #(new_context, vfn) <- result.try(
        validator_fn(Context(..context, current_node: json), fn(context) {
          generate_validator(context, context.current_node)
        }),
      )

      Ok(#(
        Context(..new_context, current_node: context.current_node),
        Some(kind(vfn)),
      ))
    }
    _ -> Ok(#(context, None))
  }
}

fn get_validation_for_type(
  context: Context,
  t: String,
) -> Result(#(types.ValueType, Context), SchemaError) {
  use #(type_check, checks) <- result.try(get_checks(t))

  use #(context, validations) <- result.try(
    list.try_fold(checks, #(context, []), fn(acc, prop) {
      let #(context, l) = acc
      case get_property(context, prop) {
        Error(e) -> Error(e)
        Ok(Some(json)) -> {
          use #(context, validation_fn) <- result.try(apply_property(
            prop,
            context,
            json,
            Validation,
          ))
          Ok(#(context, [validation_fn, ..l]))
        }
        Ok(None) -> Ok(acc)
      }
    }),
  )

  use #(context, sub_validations) <- result.try(case type_check {
    types.Array(_) -> {
      use subval <- result.try(get_array_subvalidation(context))
      Ok(subval)
    }
    types.Object(_) -> {
      use subval <- result.try(get_object_subvalidation(context))
      Ok(subval)
    }
    _ -> Ok(#(context, [None]))
  })

  use #(context, subschema) <- result.try(get_subschemas(context))

  use then <- result.try(get_validation_property(context, "then"))
  let context = option.unwrap(then, context)
  use orelse <- result.try(get_validation_property(context, "else"))
  let context = option.unwrap(orelse, context)
  use if_validation <- result.try(get_validation_property(context, "if"))
  let context = option.unwrap(if_validation, context)

  let ifthen = [
    case if_validation {
      Some(Context(_, Some(if_validator), _, _)) ->
        Some(types.IfThenValidation(
          if_validator,
          then |> to_validator,
          orelse |> to_validator,
        ))
      _ -> None
    },
  ]

  use #(context, unevaluated) <- result.try(case type_check {
    types.Array(_) -> {
      get_unevaluated(context, "unevaluatedItems", array.unevaluated_items)
    }
    types.Object(_) -> {
      get_unevaluated(
        context,
        "unevaluatedProperties",
        object.unevaluated_properties,
      )
    }
    _ -> Ok(#(context, None))
  })

  #(
    type_check,
    case
      [
        sub_validations,
        validations,
        subschema,
        ifthen,
        [unevaluated],
      ]
      |> list.flatten
      |> option.values
    {
      [] -> add_validator_to_context(context, SimpleValidation(True))
      [v] -> add_validator_to_context(context, v)
      v ->
        add_validator_to_context(
          context,
          MultipleValidation(v, types.All, function.identity, False),
        )
    },
  )
  |> Ok
}

fn get_unevaluated(
  context: Context,
  prop: String,
  uneval_fn: fn(Context, fn(Context) -> Result(Context, SchemaError)) ->
    Result(
      #(
        Context,
        fn(JsonValue, Schema, NodeAnnotation) ->
          #(ValidationInfo, NodeAnnotation),
      ),
      SchemaError,
    ),
) -> Result(#(Context, Option(ValidationNode)), SchemaError) {
  let prop =
    ValidatorProperties(
      prop,
      types.Types([types.Object(types.AnyType), types.Boolean]),
      types.ok_fn,
      Some(uneval_fn),
    )
  case get_property(context, prop) {
    Error(e) -> Error(e)
    Ok(Some(json)) -> {
      apply_property(prop, context, json, types.PostValidation)
    }
    Ok(None) -> Ok(#(context, None))
  }
}

fn get_subschemas(
  context: Context,
) -> Result(#(Context, List(Option(ValidationNode))), SchemaError) {
  use all_of <- result.try(get_validator_list(context, "allOf"))
  use any_of <- result.try(get_validator_list(context, "anyOf"))
  use one_of <- result.try(get_validator_list(context, "oneOf"))

  let context = construct_new_context(context, [all_of, any_of, one_of])

  let all_of = utils.unwrap_to_multiple(all_of, types.All)
  let any_of = utils.unwrap_to_multiple(any_of, types.Any)
  let one_of = utils.unwrap_to_multiple(one_of, types.One)

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
      option.map(i, jsonvalue_to_validation("not", _, context))
      |> unwrap_option_result
    }),
  )
  let context = option.unwrap(not, context)

  let not = option.map(not |> to_validator, types.NotValidation)

  Ok(#(context, [all_of, any_of, one_of, not]))
}

fn get_array_subvalidation(
  context: Context,
) -> Result(#(Context, List(Option(ValidationNode))), SchemaError) {
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
      option.map(i, jsonvalue_to_validation("items", _, context))
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
      option.map(v, jsonvalue_to_validation("contains", _, context))
      |> unwrap_option_result
    }),
  )

  let context =
    construct_new_context(context, [
      prefix_items,
      items |> option.map(list.wrap),
      contains |> option.map(list.wrap),
    ])
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
  Ok(
    #(
      context,
      case
        option.is_some(prefix_items)
        || option.is_some(items)
        || option.is_some(contains)
      {
        True -> [
          Some(ArraySubValidation(
            prefix_items |> option.map(utils.unwrap_context_list),
            items |> to_validator,
            contains
              |> to_validator,
          )),
          min_contains,
        ]
        False -> [None]
      },
    ),
  )
}

fn to_validator(context: Option(Context)) -> Option(ValidationNode) {
  context |> option.map(fn(c) { c.current_validator }) |> option.flatten
}

fn get_validator_list(
  context: Context,
  prop_name: String,
) -> Result(Option(List(Context)), SchemaError) {
  get_property(
    context,
    Property(
      prop_name,
      types.Array(types.Types([types.Object(types.AnyType), types.Boolean])),
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
            generate_validator(context, i)
          })
        }
        _ -> Error(SchemaError)
      }
    })
    |> unwrap_option_result
  })
}

fn jsonvalue_to_validation(
  prop_name: String,
  v: JsonValue,
  context: Context,
) -> Result(Context, SchemaError) {
  case v {
    JsonObject(_, _) | JsonBool(_, _) -> generate_validator(context, v)
    _ -> Error(types.InvalidProperty(prop_name, context.current_node))
  }
}

fn get_object_subvalidation(
  context: Context,
) -> Result(#(Context, List(Option(ValidationNode))), SchemaError) {
  let p =
    Property(
      "properties",
      types.Object(types.Types([types.Object(types.AnyType), types.Boolean])),
      types.ok_fn,
      None,
    )

  use #(context, properties) <- result.try(
    get_property(context, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(#(context, None))
        Some(JsonObject(d, _)) -> {
          dict_to_validations(d, context, Ok)
          |> result.map(fn(e) {
            let #(context, properties) = e
            #(context, Some(properties))
          })
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

  use #(context, pattern_properties) <- result.try(
    get_property(context, p)
    |> result.try(fn(v) {
      case v {
        None -> Ok(#(context, None))
        Some(JsonObject(d, _)) -> {
          dict_to_validations(d, context, fn(k) {
            regexp.compile(k, regexp.Options(False, False))
            |> result.replace_error(InvalidType(context.current_node, p))
          })
          |> result.map(fn(r) {
            let #(context, d) = r
            #(context, Some(dict.to_list(d)))
          })
        }
        Some(_) -> Error(InvalidType(context.current_node, p))
      }
    }),
  )

  use additional_properties <- result.try(get_validation_property(
    context,
    "additionalProperties",
  ))

  let context = option.unwrap(additional_properties, context)

  case
    option.is_some(properties)
    || option.is_some(additional_properties)
    || option.is_some(pattern_properties)
  {
    True ->
      Ok(
        #(context, [
          Some(types.ObjectSubValidation(
            properties,
            pattern_properties,
            additional_properties
              |> to_validator,
          )),
        ]),
      )
    False -> Ok(#(context, [None]))
  }
}

fn get_validation_property(
  context: Context,
  prop_name: String,
) -> Result(Option(Context), SchemaError) {
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
    option.map(i, jsonvalue_to_validation(prop_name, _, context))
    |> unwrap_option_result
  })
}

fn dict_to_validations(
  d: dict.Dict(String, JsonValue),
  context: Context,
  km: fn(String) -> Result(k, SchemaError),
) -> Result(#(Context, dict.Dict(k, ValidationNode)), SchemaError) {
  use l <- result.try(
    dict.to_list(d)
    |> list.try_map(fn(e) {
      case e {
        #(k, JsonObject(_, _) as jv) | #(k, JsonBool(_, _) as jv) -> {
          use k <- result.try(km(k))
          generate_validator(context, jv)
          |> result.map(fn(v) { #(k, v) })
        }
        _ -> Error(SchemaError)
      }
    }),
  )
  let context =
    list.map(l, fn(e) {
      let #(_k, c) = e
      c
    })
    |> list.fold(context, fn(context, new_context) {
      merge_context(context, new_context)
    })

  Ok(#(
    context,
    dict.from_list(
      list.filter_map(l, fn(e) {
        let #(k, c) = e
        case c.current_validator {
          Some(v) -> Ok(#(k, v))
          None -> Error(Nil)
        }
      }),
    ),
  ))
  //|> result.map(fn(l) { Some(dict.from_list(l)) })
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
