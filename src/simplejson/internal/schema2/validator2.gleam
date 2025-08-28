import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import simplejson/internal/schema2/types.{
  type NodeAnnotation, type Schema, type ValidationInfo, type ValidationNode,
  type ValueType, AlwaysFail, ArrayAnnotation, MultipleInfo, NoAnnotation,
  NoTypeYet, ObjectAnnotation, Schema, SchemaFailure, Valid,
}
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject}

pub fn validate(
  json: JsonValue,
  schema: Schema,
) -> #(Bool, Option(ValidationInfo)) {
  let Schema(_id, _def, _schema, _refs, validator) = schema

  case do_validate(json, validator, schema, NoAnnotation) {
    #(Valid, _) -> #(True, None)
    #(_ as err, _) -> #(False, Some(err))
  }
}

pub fn do_validate(
  json: JsonValue,
  validator: ValidationNode,
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case validator {
    types.ArraySubValidation(prefix, items, contains) ->
      do_array_validation(json, prefix, items, contains, schema, annotation)
    types.IfThenValidation(when:, then:, orelse:) -> {
      case do_validate(json, when, schema, NoAnnotation) {
        #(Valid, annotation) ->
          case then {
            Some(then) -> {
              let #(v, thenann) = do_validate(json, then, schema, annotation)
              #(v, types.do_merge_annotations([annotation, thenann]))
            }
            None -> #(Valid, annotation)
          }
        #(_, annotation) ->
          case orelse {
            Some(orelse) -> {
              let #(v, thenann) = do_validate(json, orelse, schema, annotation)
              #(v, types.do_merge_annotations([annotation, thenann]))
            }
            None -> #(Valid, annotation)
          }
      }
    }
    types.MultipleValidation(
      tests:,
      combination:,
      map_error:,
      isolate_annotation:,
    ) -> {
      case
        {
          case
            do_multiple_validation(
              json,
              tests,
              combination,
              schema,
              annotation,
              isolate_annotation,
            )
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
    types.ObjectSubValidation(props:, pattern_props:, additional_prop:) -> {
      do_object_validation(
        json,
        props,
        pattern_props,
        additional_prop,
        schema,
        annotation,
      )
    }
    types.SimpleValidation(valid:) -> {
      case valid {
        True -> {
          // let annotation = case json, annotation {
          //   JsonObject(d, _), ObjectAnnotation(matches) -> {
          //     ObjectAnnotation(
          //       dict.keys(d)
          //       |> list.fold(matches, fn(m, k) { dict.insert(m, k, Nil) }),
          //     )
          //   }
          //   _, _ -> annotation
          // }
          #(Valid, annotation)
        }
        False -> #(AlwaysFail, annotation)
      }
    }
    types.TypeValidation(types:) -> {
      validate_type(types, json, schema, annotation)
    }
    types.Validation(valid:) -> valid(json, schema, annotation)
    types.NotValidation(validation:) -> {
      case do_validate(json, validation, schema, annotation) {
        #(Valid, _) -> #(types.NotBeValid, annotation)
        #(_, _) -> #(Valid, annotation)
      }
    }
    types.RefValidation(jsonpointer:) -> todo as jsonpointer
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
        let assert ObjectAnnotation(matches) = state.1
        case do_validate(v, validation, schema, NoAnnotation) {
          #(Valid, _) ->
            Continue(#(Valid, ObjectAnnotation(dict.insert(matches, k, Nil))))
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
  let assert ObjectAnnotation(matches) = annotation
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
        let assert ObjectAnnotation(matches) = state.1
        let #(key, value) = entry
        let validators = get_matching_properties(key, patterns)
        case validators {
          [] -> Ok(#(Valid, state.1))
          _ -> {
            let valid =
              list.fold_until(validators, Valid, fn(state, validation) {
                case do_validate(value, validation, schema, NoAnnotation) {
                  #(Valid, _) -> Continue(state)
                  #(err, _) -> Stop(err)
                }
              })
            case valid {
              Valid ->
                Ok(#(valid, ObjectAnnotation(dict.insert(matches, key, Nil))))
              _ -> Error(#(valid, state.1))
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
        let assert ObjectAnnotation(matches) = state.1
        let #(key, value) = entry
        case dict.get(props, key) {
          Ok(validation) -> {
            case do_validate(value, validation, schema, NoAnnotation) {
              #(Valid, _) ->
                Ok(#(Valid, ObjectAnnotation(dict.insert(matches, key, Nil))))
              #(err, _) -> Error(#(err, state.1))
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
        Error(_) -> #(types.InvalidMatch("prefixItems", json), annotation)
        Ok(#(_, True)) -> {
          let assert ArrayAnnotation(_, _, c, ca) = annotation
          #(Valid, ArrayAnnotation(None, Some(True), c, ca))
        }
        Ok(#(i, _)) if i >= 0 -> {
          let assert ArrayAnnotation(_, _, c, ca) = annotation
          #(Valid, ArrayAnnotation(Some(i), Some(False), c, ca))
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
      case do_validate(json, validation, schema, NoAnnotation) {
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
      let assert ArrayAnnotation(ii, ia, c, ca) = annotation
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
          case do_validate(json, validation, schema, NoAnnotation) {
            #(Valid, _) -> False
            _ -> True
          }
        })
      let annotation = ArrayAnnotation(ii, Some(result.is_error(found)), c, ca)
      case found {
        Error(_) -> #(Valid, annotation)
        Ok(_) -> #(types.InvalidMatch("items", json), annotation)
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
            case do_validate(node, n, schema, NoAnnotation) {
              #(Valid, _) -> [i, ..matches]
              _ -> matches
            }
          },
        )
      types.do_merge_annotations([
        annotation,
        ArrayAnnotation(
          None,
          None,
          Some(matches),
          Some(list.length(matches) == dict.size(d)),
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
  isolate_annotation: Bool,
) -> #(Bool, List(ValidationInfo), NodeAnnotation) {
  let comp = case combination {
    types.All -> validate_all
    types.Any -> validate_any
    types.One -> validate_one
  }
  case comp(json, validators, schema, annotation, isolate_annotation) {
    #([Valid], ann) -> {
      let ann = case isolate_annotation {
        True -> types.do_merge_annotations([annotation, ann])
        False -> ann
      }
      #(True, [Valid], ann)
    }
    #(errors, _) -> {
      #(False, list.unique(errors), annotation)
    }
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
        #(Valid, _), 1 -> Stop(#([types.MatchOnlyOne], return_annotation, 2))
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
  let initial_annotation = case isolate_annotation {
    True -> NoAnnotation
    False -> annotation
  }
  let #(v, a) =
    list.fold_until(validators, #([], [initial_annotation]), fn(infos, v) {
      let #(_, annotations) = infos
      case
        do_validate(json, v, schema, case isolate_annotation {
          True -> initial_annotation
          False -> {
            let assert Ok(a) = list.first(annotations)
            a
          }
        })
      {
        #(Valid, ann) ->
          Continue(
            #([Valid], case isolate_annotation {
              True -> [ann, ..annotations]
              False -> [ann]
            }),
          )
        #(v, _) -> Stop(#([v], annotations))
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

fn validate_any(
  json: JsonValue,
  validators: List(ValidationNode),
  schema: Schema,
  annotation: NodeAnnotation,
  isolate_annotation: Bool,
) -> #(List(ValidationInfo), NodeAnnotation) {
  let initial_annotation = case isolate_annotation {
    True -> NoAnnotation
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
  types: dict.Dict(ValueType, ValidationNode),
  json: JsonValue,
  schema: Schema,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case
    dict.to_list(types)
    |> list.fold_until(#(NoTypeYet, annotation), fn(v, t) {
      let #(vt, validator) = t
      case is_type(vt, json) {
        True -> {
          let annotation = case annotation, vt {
            NoAnnotation, types.Array(_) ->
              ArrayAnnotation(None, None, None, None)
            NoAnnotation, types.Object(_) -> ObjectAnnotation(dict.new())
            _, _ -> annotation
          }
          Stop(do_validate(json, validator, schema, annotation))
        }
        False -> {
          #(
            case v {
              #(NoTypeYet, _) -> types.IncorrectType(vt, json)
              #(types.IncorrectType(_, _) as v, _) ->
                types.MultipleInfo([types.IncorrectType(vt, json), v])
              #(types.MultipleInfo(mi), _) ->
                types.MultipleInfo([types.IncorrectType(vt, json), ..mi])
              _ -> todo
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

fn is_type(t: ValueType, json: JsonValue) -> Bool {
  case t {
    types.AnyType -> True
    types.Array(_) -> {
      case json {
        jsonvalue.JsonArray(_, _) -> {
          True
        }
        _ -> False
      }
    }
    types.Boolean -> {
      case json {
        jsonvalue.JsonBool(_, _) -> {
          True
        }
        _ -> False
      }
    }
    types.Integer -> {
      case json {
        jsonvalue.JsonNumber(Some(_), _, _) -> True
        jsonvalue.JsonNumber(_, Some(f), _) -> {
          float.floor(f) == f
        }
        _ -> False
      }
    }
    types.Null -> {
      case json {
        jsonvalue.JsonNull(_) -> {
          True
        }
        _ -> False
      }
    }
    types.Number -> {
      case json {
        jsonvalue.JsonNumber(_, _, _) -> {
          True
        }
        _ -> False
      }
    }
    types.Object(_) -> {
      case json {
        jsonvalue.JsonObject(_, _) -> {
          True
        }
        _ -> False
      }
    }
    types.String -> {
      case json {
        jsonvalue.JsonString(_, _) -> {
          True
        }
        _ -> False
      }
    }
    types.NoType -> False
    types.Types(l) -> {
      list.any(l, is_type(_, json))
    }
  }
}
