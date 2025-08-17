import gleam/float
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema2/types.{
  type Schema, type ValidationInfo, type ValidationNode, type ValueType,
  AlwaysFail, MultipleErrors, MultipleInfo, Schema, Valid,
}
import simplejson/jsonvalue.{type JsonValue}

pub fn validate(
  json: JsonValue,
  schema: Schema,
) -> #(Bool, Option(ValidationInfo)) {
  let Schema(_id, _def, _schema, validator) = schema
  case do_validate(json, validator) {
    Valid -> #(True, None)
    _ as err -> #(False, Some(err))
  }
}

fn do_validate(json: JsonValue, validator: ValidationNode) -> ValidationInfo {
  case validator {
    types.ArraySubValidation(_, _, _) -> todo
    types.IfThenValidation(when:, then:) -> {
      case do_validate(json, when) {
        Valid -> do_validate(json, then)
        v -> v
      }
    }
    types.MultipleValidation(tests:, combination:, map_error:) -> {
      case
        {
          case do_multiple_validation(json, tests, combination) {
            #(True, _) -> [Valid]
            #(False, [vi]) -> map_error([vi])
            #(False, vis) -> map_error(vis)
          }
        }
      {
        [v] -> v
        v -> MultipleInfo(v)
      }
    }
    types.ObjectSubValidation(_, _, _) -> todo
    types.SimpleValidation(valid:) -> {
      case valid {
        True -> Valid
        False -> AlwaysFail
      }
    }
    types.TypeValidation(t:) -> {
      case validate_type(t, json) {
        True -> Valid
        False -> types.IncorrectType(t, json)
      }
    }
    types.Validation(valid:) -> valid(json)
  }
}

fn do_multiple_validation(
  json: JsonValue,
  validators: List(ValidationNode),
  combination: types.Combination,
) -> #(Bool, List(ValidationInfo)) {
  let comp = case combination {
    types.All -> validate_all
    types.Any -> validate_any
  }
  case comp(json, validators) {
    [Valid] -> #(True, [Valid])
    errors -> {
      #(False, list.unique(errors))
    }
  }
}

fn validate_all(
  json: JsonValue,
  validators: List(ValidationNode),
) -> List(ValidationInfo) {
  list.fold_until(validators, [], fn(_, v) {
    case do_validate(json, v) {
      Valid -> Continue([Valid])
      _ as info -> Stop([info])
    }
  })
}

fn validate_any(
  json: JsonValue,
  validators: List(ValidationNode),
) -> List(ValidationInfo) {
  list.fold_until(validators, [], fn(infos, v) {
    case do_validate(json, v) {
      Valid -> Stop([Valid])
      _ as info -> Continue([info, ..infos])
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
        jsonvalue.JsonNumber(Some(_), _, _, _) -> True
        jsonvalue.JsonNumber(_, Some(f), _, _) -> {
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
        jsonvalue.JsonNumber(_, _, _, _) -> {
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
    types.Types(l) -> {
      list.any(l, validate_type(_, json))
    }
  }
}
