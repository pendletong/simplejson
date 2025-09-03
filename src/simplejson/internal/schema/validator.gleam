import gleam/bool
import gleam/dict.{type Dict}
import gleam/function
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri}
import simplejson/internal/pointer
import simplejson/internal/schema/types.{
  type NodeAnnotation, type Schema, type SchemaInfo, type ValidationInfo,
  type ValidationNode, type ValueType, AlwaysFail, ArrayAnnotation,
  ArraySubValidation, FinishLevel, IfThenValidation, IncorrectType, InvalidMatch,
  InvalidRef, MatchOnlyOne, MultipleInfo, MultipleValidation, NoTypeYet,
  NodeAnnotation, NotBeValid, NotValidation, ObjectAnnotation,
  ObjectSubValidation, PostValidation, RefValidation, Schema, SimpleValidation,
  TypeValidation, Valid, Validation,
}
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject}

pub fn validate(
  json: JsonValue,
  schema: Schema,
) -> #(Bool, Option(ValidationInfo)) {
  let Schema(_id, _def, _schema, _refs, validator) = schema

  case do_validate(json, validator, schema, NodeAnnotation([], None, None)) {
    #(Valid, _) -> #(True, None)
    #(_ as err, _) -> #(False, Some(err))
  }
}

fn do_finish_level(
  json: JsonValue,
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case annotation, json {
    NodeAnnotation([], _, _), _ -> #(Valid, NodeAnnotation([], None, None))
    NodeAnnotation(post_validation, _, _), jsonvalue.JsonObject(_, _)
    | NodeAnnotation(post_validation, _, _), jsonvalue.JsonArray(_, _)
    -> {
      do_validate(
        json,
        MultipleValidation(post_validation, types.All, function.identity),
        schema,
        NodeAnnotation(..annotation, post_validation: []),
      )
      // #(v, NodeAnnotation([], None, None))
    }
    _, _ -> #(Valid, NodeAnnotation([], None, None))
  }
}

fn do_if_then(
  json: JsonValue,
  schema: Schema,
  annotation: NodeAnnotation,
  when: ValidationNode,
  then: Option(ValidationNode),
  orelse: Option(ValidationNode),
) -> #(ValidationInfo, NodeAnnotation) {
  case do_validate(json, when, schema, NodeAnnotation([], None, None)) {
    #(Valid, annotation) ->
      case then {
        Some(then) -> {
          let #(v, thenann) = do_validate(json, then, schema, annotation)
          #(v, types.do_merge_annotations([annotation, thenann]))
        }
        None -> #(Valid, annotation)
      }
    #(_, _) ->
      case orelse {
        Some(orelse) -> {
          let #(v, thenann) = do_validate(json, orelse, schema, annotation)
          #(v, types.do_merge_annotations([annotation, thenann]))
        }
        None -> #(Valid, annotation)
      }
  }
}

pub fn do_validate(
  json: JsonValue,
  validator: ValidationNode,
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case validator {
    FinishLevel -> do_finish_level(json, schema, annotation)
    ArraySubValidation(prefix, items, contains) ->
      do_array_validation(json, prefix, items, contains, schema, annotation)
    IfThenValidation(when:, then:, orelse:) -> {
      do_if_then(json, schema, annotation, when, then, orelse)
    }
    MultipleValidation(tests:, combination:, map_error:) ->
      do_multiple_validation(
        json,
        tests,
        combination,
        schema,
        annotation,
        map_error,
      )
    ObjectSubValidation(props:, pattern_props:, additional_prop:) -> {
      do_object_validation(
        json,
        props,
        pattern_props,
        additional_prop,
        schema,
        annotation,
      )
    }
    SimpleValidation(valid:) -> {
      case valid {
        True -> #(Valid, annotation)
        False -> #(AlwaysFail, annotation)
      }
    }
    TypeValidation(types:) -> {
      validate_type(types, json, schema, annotation)
    }
    Validation(valid:) -> valid(json, schema, annotation)
    PostValidation(valid:) -> {
      #(
        Valid,
        NodeAnnotation(..annotation, post_validation: [
          Validation(valid),
          ..annotation.post_validation
        ]),
      )
    }
    NotValidation(validation:) -> {
      case do_validate(json, validation, schema, annotation) {
        #(Valid, _) -> #(NotBeValid, annotation)
        #(_, _) -> #(Valid, annotation)
      }
    }
    RefValidation(ref:) -> {
      do_ref_validation(json, schema, ref)
    }
  }
}

fn get_ref(ref: Uri, info: SchemaInfo) -> Result(ValidationNode, Nil) {
  case dict.get(info.refs, ref) {
    Ok(json) -> {
      case dict.get(info.validators, json) {
        Ok(Some(v)) -> Ok(v)
        _ -> Error(Nil)
      }
    }
    Error(_) -> {
      let Uri(_scheme, _userinfo, _host, _port, _path, _query, fragment:) = ref
      let root_uri = Uri(..ref, fragment: None)
      let root = case dict.get(info.refs, root_uri) {
        Ok(json) -> json
        _ -> panic as { "uri not implemented yet " <> uri.to_string(root_uri) }
      }
      let fragment = fragment |> option.unwrap("")
      let fragment = case string.starts_with(fragment, "#") {
        True -> fragment
        False -> "#" <> fragment
      }
      case pointer.jsonpointer(root, fragment) {
        Error(_) -> Error(Nil)
        Ok(schema_json) -> {
          case dict.get(info.validators, schema_json) {
            Ok(Some(v)) -> Ok(v)
            _ -> Error(Nil)
          }
        }
      }
    }
  }
}

fn do_ref_validation(
  json: JsonValue,
  schema: Schema,
  ref: Uri,
) -> #(ValidationInfo, NodeAnnotation) {
  case get_ref(ref, schema.info) {
    Ok(validator) ->
      do_validate(json, validator, schema, NodeAnnotation([], None, None))
    Error(_) -> #(
      InvalidRef(uri.to_string(ref)),
      NodeAnnotation([], None, None),
    )
  }
}

fn do_object_validation(
  json: JsonValue,
  props: Option(Dict(String, ValidationNode)),
  patterns: Option(List(#(Regexp, ValidationNode))),
  extra: Option(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  let #(valid, annotation) =
    do_properties_validation(json, props, schema, annotation)
  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))
  let #(valid, annotation) =
    do_patterns_validation(json, patterns, schema, annotation)

  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))

  do_extras_validation(json, extra, schema, annotation)
}

fn do_extras_validation(
  json: JsonValue,
  extra: Option(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
) {
  case extra {
    Some(validation) -> {
      get_unused_properties(json, annotation)
      |> list.fold_until(#(Valid, annotation), fn(state, entry) {
        let #(k, v) = entry
        let ObjectAnnotation(matches) = types.get_object_annotation(state.1)
        case
          do_validate(v, validation, schema, NodeAnnotation([], None, None))
        {
          #(Valid, _) ->
            Continue(#(
              Valid,
              NodeAnnotation(
                ..annotation,
                object_annotation: Some(
                  ObjectAnnotation(dict.insert(matches, k, Nil)),
                ),
              ),
            ))
          #(err, _) -> Stop(#(err, annotation))
        }
      })
    }
    None -> #(Valid, annotation)
  }
}

pub fn get_unused_properties(
  json: JsonValue,
  annotation: NodeAnnotation,
) -> List(#(String, JsonValue)) {
  let ObjectAnnotation(matches) = types.get_object_annotation(annotation)
  let assert JsonObject(d, _) = json
  list.filter(dict.to_list(d), fn(e) {
    let #(k, _) = e
    !dict.has_key(matches, k)
  })
}

fn do_patterns_validation(
  json: JsonValue,
  patterns: Option(List(#(Regexp, ValidationNode))),
  schema: Schema,
  annotation: NodeAnnotation,
) {
  let assert JsonObject(d, _) = json
  case patterns {
    Some(patterns) -> {
      dict.to_list(d)
      |> list.try_fold(#(Valid, annotation), fn(state, entry) {
        let #(_, annotation) = state
        let #(key, value) = entry
        let validators = get_matching_properties(key, patterns)
        case validators {
          [] -> Ok(#(Valid, annotation))
          _ -> {
            let valid =
              list.fold_until(validators, Valid, fn(state, validation) {
                case
                  do_validate(
                    value,
                    validation,
                    schema,
                    NodeAnnotation([], None, None),
                  )
                {
                  #(Valid, _) -> Continue(state)
                  #(err, _) -> Stop(err)
                }
              })
            case valid {
              Valid -> {
                let ObjectAnnotation(matches) =
                  types.get_object_annotation(annotation)
                Ok(#(
                  valid,
                  NodeAnnotation(
                    ..annotation,
                    object_annotation: Some(
                      ObjectAnnotation(dict.insert(matches, key, Nil)),
                    ),
                  ),
                ))
              }
              _ -> Error(#(valid, annotation))
            }
          }
        }
      })
      |> result.unwrap_both
    }
    None -> #(Valid, annotation)
  }
}

fn get_matching_properties(
  key: String,
  patterns: List(#(Regexp, ValidationNode)),
) -> List(ValidationNode) {
  list.filter_map(patterns, fn(p) {
    let #(r, validation) = p
    case regexp.check(r, key) {
      True -> Ok(validation)
      False -> Error(Nil)
    }
  })
}

fn do_properties_validation(
  json: JsonValue,
  props: Option(Dict(String, ValidationNode)),
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  let assert JsonObject(d, _) = json
  case props {
    Some(props) -> {
      dict.to_list(d)
      |> list.try_fold(#(Valid, annotation), fn(state, entry) {
        let #(key, value) = entry
        let #(_, annotation) = state
        case dict.get(props, key) {
          Ok(validation) -> {
            case
              do_validate(
                value,
                validation,
                schema,
                NodeAnnotation([], None, None),
              )
            {
              #(Valid, _) -> {
                let ObjectAnnotation(matches) =
                  types.get_object_annotation(annotation)
                Ok(#(
                  Valid,
                  NodeAnnotation(
                    ..annotation,
                    object_annotation: Some(
                      ObjectAnnotation(dict.insert(matches, key, Nil)),
                    ),
                  ),
                ))
              }
              #(err, _) -> Error(#(err, annotation))
            }
          }
          Error(_) -> Ok(state)
        }
      })
      |> result.unwrap_both
    }
    None -> #(Valid, annotation)
  }
}

fn do_array_validation(
  json: JsonValue,
  prefix: Option(List(ValidationNode)),
  items: Option(ValidationNode),
  contains: Option(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  let #(valid, annotation) =
    do_prefix_items_validation(json, prefix, schema, annotation)

  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))

  let #(valid, annotation) =
    do_items_validation(json, items, schema, annotation)

  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))

  let annotation = do_contains_validation(json, contains, schema, annotation)

  #(Valid, annotation)
}

fn do_prefix_items_validation(
  json: JsonValue,
  prefix: Option(List(ValidationNode)),
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case prefix {
    Some(l) -> {
      let assert JsonArray(d, _) = json
      let actual_list = stringify.dict_to_ordered_list(d)
      case apply_prefix_items(actual_list, l, -1, schema) {
        Error(_) -> #(InvalidMatch("prefixItems", json), annotation)
        Ok(#(_, True)) -> {
          let ArrayAnnotation(_, _, c, ca) =
            types.get_array_annotation(annotation)
          #(
            Valid,
            NodeAnnotation(
              ..annotation,
              array_annotation: Some(ArrayAnnotation(None, Some(True), c, ca)),
            ),
          )
        }
        Ok(#(i, _)) if i >= 0 -> {
          let ArrayAnnotation(_, _, c, ca) =
            types.get_array_annotation(annotation)
          #(
            Valid,
            NodeAnnotation(
              ..annotation,
              array_annotation: Some(ArrayAnnotation(
                Some(i),
                Some(False),
                c,
                ca,
              )),
            ),
          )
        }
        Ok(_) -> {
          #(Valid, annotation)
        }
      }
    }
    None -> #(Valid, annotation)
  }
}

fn apply_prefix_items(
  actual_list: List(JsonValue),
  compare: List(ValidationNode),
  index: Int,
  schema: Schema,
) -> Result(#(Int, Bool), Int) {
  case actual_list, compare {
    [], [] -> Ok(#(index, True))
    [], _ -> Ok(#(index, True))
    _, [] -> Ok(#(index, False))
    [json, ..rest], [validation, ..vrest] -> {
      case
        do_validate(json, validation, schema, NodeAnnotation([], None, None))
      {
        #(Valid, _) -> apply_prefix_items(rest, vrest, index + 1, schema)
        _ -> Error(index)
      }
    }
  }
}

fn do_items_validation(
  json: JsonValue,
  items: Option(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
) {
  case items {
    Some(validation) -> {
      let ArrayAnnotation(ii, ia, c, ca) =
        types.get_array_annotation(annotation)
      use <- bool.guard(when: ia == Some(True), return: #(Valid, annotation))
      let initial_index = case ii {
        Some(i) -> i + 1
        None -> 0
      }

      let assert JsonArray(d, _) = json
      let found =
        stringify.dict_to_ordered_list(d)
        |> list.drop(initial_index)
        |> list.find(fn(json) {
          case
            do_validate(
              json,
              validation,
              schema,
              NodeAnnotation([], None, None),
            )
          {
            #(Valid, _) -> False
            _ -> True
          }
        })
      let annotation =
        NodeAnnotation(
          ..annotation,
          array_annotation: Some(ArrayAnnotation(
            ii,
            Some(result.is_error(found)),
            c,
            ca,
          )),
        )
      case found {
        Error(_) -> #(Valid, annotation)
        Ok(_) -> #(InvalidMatch("items", json), annotation)
      }
    }
    None -> #(Valid, annotation)
  }
}

fn do_contains_validation(
  json: JsonValue,
  contains: Option(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
) -> NodeAnnotation {
  case contains {
    Some(n) -> {
      let assert JsonArray(d, _) = json
      let matches =
        list.index_fold(
          stringify.dict_to_ordered_list(d),
          [],
          fn(matches, node, i) {
            case do_validate(node, n, schema, NodeAnnotation([], None, None)) {
              #(Valid, _) -> [i, ..matches]
              _ -> matches
            }
          },
        )
      types.do_merge_annotations([
        annotation,
        NodeAnnotation(
          [],
          Some(ArrayAnnotation(
            None,
            None,
            Some(matches),
            Some(list.length(matches) == dict.size(d)),
          )),
          None,
        ),
      ])
    }
    _ -> annotation
  }
}

fn do_multiple_validation(
  json: JsonValue,
  validators: List(ValidationNode),
  combination: types.Combination,
  schema: Schema,
  annotation: NodeAnnotation,
  map_error: fn(List(ValidationInfo)) -> List(ValidationInfo),
) -> #(ValidationInfo, NodeAnnotation) {
  case
    {
      case
        {
          let #(comp, annotation, isolate) = case combination {
            types.All -> #(validate_all, annotation, False)
            types.AllOf -> {
              #(validate_all, NodeAnnotation([], None, None), True)
            }
            types.Any -> #(validate_any, annotation, False)
            types.AnyOf -> #(validate_any, NodeAnnotation([], None, None), True)
            types.OneOf -> #(validate_one, annotation, False)
          }
          case comp(json, validators, schema, annotation, isolate) {
            #([Valid], ann) -> {
              let ann = case isolate {
                True ->
                  NodeAnnotation(
                    ..types.do_merge_annotations([annotation, ann]),
                    post_validation: [],
                  )
                False -> ann
              }
              #(True, [Valid], ann)
            }
            #(errors, _) -> {
              #(False, list.unique(errors), annotation)
            }
          }
        }
      {
        #(True, _, ann) -> #([Valid], ann)
        #(False, [vi], ann) -> #(map_error([vi]), ann)
        #(False, vis, ann) -> #(map_error(vis), ann)
      }
    }
  {
    #([v], ann) -> #(v, ann)
    #(v, ann) -> #(MultipleInfo(v), ann)
  }
}

fn validate_one(
  json: JsonValue,
  validators: List(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
  _merge_annotations: Bool,
) -> #(List(ValidationInfo), NodeAnnotation) {
  let #(v, annotation, _) =
    list.fold_until(validators, #([], annotation, 0), fn(infos, v) {
      let #(validity, return_annotation, i) = infos
      case do_validate(json, v, schema, annotation), i {
        #(Valid, ann), 0 -> Continue(#([Valid], ann, 1))
        #(Valid, _), 1 -> Stop(#([MatchOnlyOne], return_annotation, 2))
        #(_, _), _ -> Continue(#(validity, return_annotation, i))
      }
    })
  #(v, annotation)
}

fn validate_all(
  json: JsonValue,
  validators: List(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
  isolate_annotation: Bool,
) -> #(List(ValidationInfo), NodeAnnotation) {
  list.fold_until(validators, #([], annotation), fn(infos, v) {
    let #(_, updated_annotation) = infos
    case
      do_validate(json, v, schema, case isolate_annotation {
        True -> annotation
        False -> updated_annotation
      })
    {
      #(Valid, ann) ->
        Continue(#(
          [Valid],
          types.do_merge_annotations([ann, updated_annotation]),
        ))
      #(v, _) -> Stop(#([v], updated_annotation))
    }
  })
}

fn validate_any(
  json: JsonValue,
  validators: List(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
  isolate_annotation: Bool,
) -> #(List(ValidationInfo), NodeAnnotation) {
  let initial_annotation = case isolate_annotation {
    True -> NodeAnnotation([], None, None)
    False -> annotation
  }
  let #(v, a) =
    list.fold(validators, #([], [initial_annotation]), fn(infos, v) {
      let #(validity, annotations) = infos
      case
        do_validate(json, v, schema, case isolate_annotation {
          True -> initial_annotation
          False -> {
            let assert Ok(a) = list.first(annotations)
            a
          }
        }),
        validity
      {
        #(Valid, ann), _ -> #([Valid], case isolate_annotation {
          True -> [ann, ..annotations]
          False -> [ann]
        })
        #(_, _), [Valid] -> #([Valid], annotations)
        #(v, _), _ -> #([v, ..validity], annotations)
      }
    })
  #(v, case isolate_annotation {
    True -> types.do_merge_annotations(a)
    False -> {
      let assert Ok(l) = list.first(a)
      l
    }
  })
}

fn validate_type(
  types: List(#(ValueType, ValidationNode)),
  json: JsonValue,
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case
    list.fold_until(types, #(NoTypeYet, annotation), fn(v, t) {
      let #(vt, validator) = t
      case types.is_type(vt, json) {
        True -> {
          let annotation = case vt {
            types.Array(_) ->
              NodeAnnotation(
                ..annotation,
                array_annotation: types.merge_array_annotations(
                  annotation.array_annotation,
                  Some(ArrayAnnotation(None, None, None, None)),
                ),
              )
            types.Object(_) ->
              NodeAnnotation(
                ..annotation,
                object_annotation: types.merge_object_annotation(
                  annotation.object_annotation,
                  Some(ObjectAnnotation(dict.new())),
                ),
              )
            _ -> annotation
          }

          Stop(do_validate(json, validator, schema, annotation))
        }
        False -> {
          #(
            case v {
              #(NoTypeYet, _) -> IncorrectType(vt, json)
              #(IncorrectType(_, _) as vi, _) ->
                MultipleInfo([IncorrectType(vt, json), vi])
              #(MultipleInfo(mi), _) ->
                MultipleInfo([IncorrectType(vt, json), ..mi])
              #(_, _) -> v.0
            },
            annotation,
          )
          |> Continue
        }
      }
    })
  {
    #(NoTypeYet, ann) -> #(Valid, ann)
    v -> v
  }
}
