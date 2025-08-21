import gleam/bool
import gleam/dict
import gleam/float
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/result
import simplejson/internal/schema2/types.{
  type NodeAnnotation, type Schema, type ValidationInfo, type ValidationNode,
  type ValueType, AlwaysFail, ArrayAnnotation, MultipleInfo, NoAnnotation,
  Schema, Todo, Valid, ValidationError,
}
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, JsonArray}

pub fn validate(
  json: JsonValue,
  schema: Schema,
) -> #(Bool, Option(ValidationInfo)) {
  let Schema(_id, _def, _schema, validator) = schema
  case do_validate(json, validator, NoAnnotation) {
    #(Valid, _) -> #(True, None)
    #(_ as err, _) -> #(False, Some(err))
  }
}

fn do_validate(
  json: JsonValue,
  validator: ValidationNode,
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case validator {
    types.ArraySubValidation(prefix, items, contains) ->
      do_array_validation(
        json,
        prefix,
        items,
        contains,
        ArrayAnnotation(None, None, None, None),
      )
    types.IfThenValidation(when:, then:) -> {
      case do_validate(json, when, annotation) {
        #(Valid, ann) -> do_validate(json, then, ann)
        v -> v
      }
    }
    types.MultipleValidation(tests:, combination:, map_error:) -> {
      case
        {
          case do_multiple_validation(json, tests, combination, annotation) {
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
    types.ObjectSubValidation(_, _, _) -> todo
    types.SimpleValidation(valid:) -> {
      case valid {
        True -> #(Valid, annotation)
        False -> #(AlwaysFail, annotation)
      }
    }
    types.TypeValidation(t:) -> {
      case validate_type(t, json) {
        True -> #(Valid, annotation)
        False -> #(types.IncorrectType(t, json), annotation)
      }
    }
    types.Validation(valid:) -> valid(json, annotation)
  }
}

fn do_array_validation(
  json: JsonValue,
  prefix: Option(List(ValidationNode)),
  items: Option(ValidationNode),
  contains: Option(ValidationNode),
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  let #(valid, annotation) =
    do_prefix_items_validation(json, prefix, annotation) |> echo

  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))

  let #(valid, annotation) = do_items_validation(json, items, annotation)

  use <- bool.guard(when: valid != Valid, return: #(valid, annotation))

  let annotation = do_contains_validation(json, contains, annotation)

  #(Valid, annotation)
}

fn do_prefix_items_validation(
  json: JsonValue,
  prefix: Option(List(ValidationNode)),
  annotation: NodeAnnotation,
) -> #(ValidationInfo, NodeAnnotation) {
  case prefix {
    Some(l) -> {
      let assert JsonArray(d, _) = json
      let actual_list = stringify.dict_to_ordered_list(d)
      case apply_prefix_items(actual_list, l, 0) {
        Error(_) -> #(types.InvalidMatch("prefixItems", json), annotation)
        Ok(i) -> {
          let assert ArrayAnnotation(_, ia, c, ca) = annotation
          #(Valid, ArrayAnnotation(Some(i), ia, c, ca))
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
) -> Result(Int, Int) {
  case actual_list, compare {
    [], [] -> Ok(index)
    [], _ -> Ok(index)
    _, [] -> Ok(index)
    [json, ..rest], [validation, ..vrest] -> {
      case do_validate(json, validation, NoAnnotation) {
        #(Valid, _) -> apply_prefix_items(rest, vrest, index + 1)
        _ -> Error(index)
      }
    }
  }
}

fn do_items_validation(
  json: JsonValue,
  items: Option(ValidationNode),
  annotation: NodeAnnotation,
) {
  case items {
    Some(validation) -> {
      let assert ArrayAnnotation(ii, _, c, ca) = annotation
      let initial_index = case ii {
        Some(i) -> i
        None -> 0
      }
      let assert JsonArray(d, _) = json
      let found =
        stringify.dict_to_ordered_list(d)
        |> list.drop(initial_index)
        |> list.find(fn(json) {
          case do_validate(json, validation, NoAnnotation) {
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
            case do_validate(node, n, NoAnnotation) {
              #(Valid, _) -> [i, ..matches]
              _ -> matches
            }
          },
        )
      let assert ArrayAnnotation(ii, ia, _, _) = annotation
      case matches {
        [] -> ArrayAnnotation(ii, ia, Some([]), Some(False))
        _ ->
          ArrayAnnotation(
            ii,
            ia,
            Some(matches),
            Some(list.length(matches) == dict.size(d)),
          )
      }
    }
    _ -> annotation
  }
}

fn do_multiple_validation(
  json: JsonValue,
  validators: List(ValidationNode),
  combination: types.Combination,
  annotation: NodeAnnotation,
) -> #(Bool, List(ValidationInfo), NodeAnnotation) {
  let comp = case combination {
    types.All -> validate_all
    types.Any -> validate_any
  }
  case comp(json, validators, annotation) {
    #([Valid], ann) -> #(True, [Valid], ann)
    #(errors, ann) -> {
      #(False, list.unique(errors), ann)
    }
  }
}

fn validate_all(
  json: JsonValue,
  validators: List(ValidationNode),
  annotation: NodeAnnotation,
) -> #(List(ValidationInfo), NodeAnnotation) {
  list.fold_until(validators, #([], annotation), fn(infos, v) {
    let #(_, annotations) = infos
    case do_validate(json, v, annotations) {
      #(Valid, ann) -> Continue(#([Valid], ann))
      #(v, ann) -> Stop(#([v], ann))
    }
  })
}

fn validate_any(
  json: JsonValue,
  validators: List(ValidationNode),
  annotation: NodeAnnotation,
) -> #(List(ValidationInfo), NodeAnnotation) {
  list.fold_until(validators, #([], annotation), fn(infos, v) {
    let #(validity, annotations) = infos
    case do_validate(json, v, annotations) {
      #(Valid, ann) -> Stop(#([Valid], ann))
      #(v, ann) -> Continue(#([v, ..validity], ann))
    }
  })
}

fn validate_type(t: ValueType, json: JsonValue) -> Bool {
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
      list.any(l, validate_type(_, json))
    }
  }
}
