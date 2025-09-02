import gleam/bool
import gleam/dict
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/uri.{type Uri, Uri}
import simplejson
import simplejson/internal/schema2/consts.{
  const_property, contains_property, defs_property, enum_property,
  get_all_checks, get_checks, items_property, not_property,
  pattern_properties_property, properties_property, schema_property,
  type_property, validator_list_property,
}
import simplejson/internal/schema2/properties/array
import simplejson/internal/schema2/properties/object
import simplejson/internal/schema2/types.{
  type Context, type NodeAnnotation, type Property, type Schema,
  type SchemaError, type ValidationInfo, type ValidationNode, ArraySubValidation,
  Context, FinishLevel, InvalidJson, InvalidType, MultipleValidation, Property,
  RefValidation, Schema, SchemaError, SchemaInfo, SimpleValidation,
  TypeValidation, Validation, ValidatorProperties,
}
import simplejson/internal/stringify

import simplejson/internal/utils.{
  add_validator_to_context, construct_new_context, merge_context,
  unwrap_option_result,
}
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
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
  let context =
    Context(
      schema_json,
      None,
      schema_json,
      SchemaInfo(dict.new(), dict.insert(dict.new(), uri.empty, schema_json)),
      [],
      uri.empty,
      [],
    )
  use schema_uri <- result.try(get_property(
    context,
    schema_property,
    // This needs to be fixed to validate uris
  ))
  case generate_validator(context, schema_json) {
    Ok(new_context) -> {
      use new_context <- result.try(post_process_refs(new_context))
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
        new_context.schema_info,
        option.unwrap(new_context.current_validator, SimpleValidation(True)),
      ))
    }
    Error(err) -> Error(err)
  }
}

fn post_process_refs(context: Context) -> Result(Context, SchemaError) {
  case context.refs_to_process {
    [] -> Ok(context)
    refs -> {
      list.try_fold(refs, context, fn(context, uri) {
        let root_uri = Uri(..uri, fragment: None)
        case dict.has_key(context.schema_info.refs, root_uri) {
          True -> Ok(context)
          False -> {
            Error(types.RemoteRef(uri.to_string(root_uri)))
          }
        }
      })
    }
  }
}

fn generate_validator(
  context: Context,
  json: JsonValue,
) -> Result(Context, SchemaError) {
  case json {
    JsonBool(b, _) -> add_validator(context, json, SimpleValidation(b))
    JsonObject(d, _) -> {
      case dict.is_empty(d) {
        True -> add_validator(context, json, SimpleValidation(True))
        _ -> {
          generate_root_validation(Context(..context, current_node: json))
          |> utils.revert_current_node(context.current_node)
        }
      }
    }
    _ -> Error(SchemaError)
  }
}

fn add_validator(
  context: Context,
  json: JsonValue,
  validator: ValidationNode,
) -> Result(Context, SchemaError) {
  Ok(add_validator_to_context(Context(..context, current_node: json), validator))
  |> utils.revert_current_node(context.current_node)
}

fn pop_id(path: List(JsonValue)) -> Result(#(JsonValue, List(JsonValue)), Nil) {
  case path {
    [] -> Error(Nil)
    [i, ..rest] -> {
      let assert JsonObject(d, _) = i
      case dict.get(d, "$id") {
        Ok(_) -> Ok(#(i, rest))
        Error(_) -> pop_id(rest)
      }
    }
  }
}

fn get_current_uri(context: Context, uri: Uri) -> Result(Uri, Nil) {
  case pop_id(context.current_path) {
    Ok(#(JsonObject(d, _), path)) -> {
      case dict.get(d, "$id") {
        Ok(JsonString(id, _)) -> {
          use parent_uri <- result.try({
            case uri.parse(id) {
              Ok(Uri(Some(_), _, _, _, _, _, _)) as uri -> uri
              Error(_) -> Error(Nil)
              _ -> get_current_uri(Context(..context, current_path: path), uri)
            }
          })
          use current_uri <- result.try(uri.merge(parent_uri, uri))
          Ok(current_uri)
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn generate_root_validation(context: Context) -> Result(Context, SchemaError) {
  use d <- result.try(case context.current_node {
    JsonObject(d, _) -> Ok(d)
    _ -> Error(SchemaError)
  })

  use context <- result.try(case dict.get(d, "$id") {
    Ok(JsonString(id, _) as v) -> {
      let uri = uri.parse(id)
      case uri {
        Ok(Uri(Some("urn"), _, _, _, _, _, _) as uri) -> {
          let schema_info =
            SchemaInfo(
              context.schema_info.validators,
              dict.insert(context.schema_info.refs, uri, context.current_node),
            )
          Ok(Context(..context, schema_info:, current_uri: uri))
        }
        Ok(Uri(_, _, None, _, _, _, _) as uri) -> {
          use current_uri <- result.try(
            get_current_uri(context, uri)
            |> result.replace_error(types.InvalidProperty("$id", v)),
          )

          let schema_info =
            SchemaInfo(
              context.schema_info.validators,
              dict.insert(
                context.schema_info.refs,
                current_uri,
                context.current_node,
              ),
            )
          Ok(Context(..context, schema_info:, current_uri:))
        }
        Ok(uri) -> {
          let schema_info =
            SchemaInfo(
              context.schema_info.validators,
              dict.insert(context.schema_info.refs, uri, context.current_node),
            )
          Ok(Context(..context, schema_info:, current_uri: uri))
        }
        Error(_) -> Error(types.InvalidProperty("$id", v))
      }
    }
    Ok(v) -> Error(types.InvalidProperty("$id", v))
    Error(_) -> Ok(context)
  })

  let context =
    Context(..context, current_path: [
      context.current_node,
      ..context.current_path
    ])

  case dict.get(d, "$dynamicRef") {
    Ok(_) -> panic
    Error(_) -> Nil
  }
  use context <- result.try(case dict.get(d, "$anchor") {
    Ok(JsonString(a, _)) -> {
      let anchor_uri = Uri(..context.current_uri, fragment: Some(a))
      let schema_info =
        SchemaInfo(
          context.schema_info.validators,
          dict.insert(
            context.schema_info.refs,
            anchor_uri,
            context.current_node,
          ),
        )
      Ok(Context(..context, schema_info:))
    }
    Ok(_) -> Error(types.InvalidProperty("$anchor", context.current_node))
    _ -> Ok(context)
  })

  use #(ref, context) <- result.try(case dict.get(d, "$ref") {
    Ok(JsonString(ref, _) as ref_json) -> {
      use uri <- result.try(
        uri.parse(ref)
        |> result.replace_error(types.InvalidProperty("$ref", ref_json)),
      )
      use uri <- result.try(case context.current_uri, uri {
        Uri(Some("urn"), _, _, _, _, _, _),
          Uri(None, None, None, None, "", None, Some(fragment))
        -> Ok(Uri(..context.current_uri, fragment: Some(fragment)))
        _, Uri(Some(_), _, _, _, _, _, _) -> Ok(uri)
        Uri(Some(_), _, _, _, _, _, _), _ -> {
          uri.merge(context.current_uri, uri)
          |> result.replace_error(types.InvalidProperty("$ref", ref_json))
        }
        _, _ -> Ok(uri)
      })

      let root_uri = Uri(..uri, fragment: None)
      let context = case dict.has_key(context.schema_info.refs, root_uri) {
        True -> context
        False -> {
          Context(
            ..context,
            refs_to_process: [uri, ..context.refs_to_process] |> list.unique,
          )
        }
      }
      Ok(#(Some(uri), context))
    }
    Ok(j) -> Error(types.InvalidProperty("$ref", j))
    Error(_) -> Ok(#(None, context))
  })

  use defs <- result.try(get_property(context, defs_property))

  use context <- result.try(case defs {
    Some(JsonObject(d, _)) -> {
      use #(context, _) <- result.try(
        dict_to_validations(d, context, fn(_, v) { Ok(v) })
        |> result.map(fn(e) {
          let #(context, properties) = e
          #(context, Some(properties))
        }),
      )
      Ok(context)
    }
    _ -> Ok(context)
  })

  use instance_type <- result.try(get_property(context, type_property))

  use enum <- result.try(get_property(context, enum_property))

  use const_val <- result.try(get_property(context, const_property))

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
    [FinishLevel] -> Error(SchemaError)
    v -> {
      Ok(add_validator_to_context(
        context,
        MultipleValidation(v, types.All, function.identity),
      ))
    }
  }
}

fn validate_enum(v: JsonValue) {
  case v {
    JsonArray(array, _) -> {
      MultipleValidation(
        list.map(dict.values(array), validate_const),
        types.Any,
        function.identity,
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
        return: Error(types.InvalidProperty("type", context.current_node)),
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
    get_all_checks()
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
      Some(Context(_, Some(if_validator), _, _, _, _, _)) ->
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
          MultipleValidation(v, types.All, function.identity),
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

  let all_of = utils.unwrap_to_multiple(all_of, types.AllOf)
  let any_of = utils.unwrap_to_multiple(any_of, types.AnyOf)
  let one_of = utils.unwrap_to_multiple(one_of, types.OneOf)

  use not <- result.try(
    get_property(context, not_property)
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
    get_property(context, items_property)
    |> result.try(fn(i) {
      option.map(i, jsonvalue_to_validation("items", _, context))
      |> unwrap_option_result
    }),
  )
  use contains <- result.try(
    get_property(context, contains_property)
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
  // This should only ever hit the first case as the property is a const!
  let prop = case validator_list_property {
    Property(_name, valuetype:, value_check:, validator_fn:) ->
      Property(prop_name, valuetype:, value_check:, validator_fn:)
    ValidatorProperties(_name, valuetype:, value_check:, validator_fn:) ->
      ValidatorProperties(prop_name, valuetype:, value_check:, validator_fn:)
  }
  get_property(context, prop)
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
  use #(context, properties) <- result.try(
    get_property(context, properties_property)
    |> result.try(fn(v) {
      case v {
        None -> Ok(#(context, None))
        Some(JsonObject(d, _)) -> {
          dict_to_validations(d, context, fn(k, _) { Ok(k) })
          |> result.map(fn(e) {
            let #(context, properties) = e
            #(context, Some(properties))
          })
        }
        Some(_) -> Error(InvalidType(context.current_node, properties_property))
      }
    }),
  )

  use #(context, pattern_properties) <- result.try(
    get_property(context, pattern_properties_property)
    |> result.try(fn(v) {
      case v {
        None -> Ok(#(context, None))
        Some(JsonObject(d, _)) -> {
          dict_to_validations(d, context, fn(k, _) {
            regexp.compile(k, regexp.Options(False, False))
            |> result.replace_error(InvalidType(
              context.current_node,
              pattern_properties_property,
            ))
          })
          |> result.map(fn(r) {
            let #(context, d) = r
            #(context, Some(dict.to_list(d)))
          })
        }
        Some(_) ->
          Error(InvalidType(context.current_node, pattern_properties_property))
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
  km: fn(String, JsonValue) -> Result(k, SchemaError),
) -> Result(#(Context, dict.Dict(k, ValidationNode)), SchemaError) {
  use l <- result.try(
    dict.to_list(d)
    |> list.try_map(fn(e) {
      case e {
        #(k, JsonObject(_, _) as jv) | #(k, JsonBool(_, _) as jv) -> {
          use k <- result.try(km(k, jv))
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
