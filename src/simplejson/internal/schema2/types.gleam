import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/order.{Gt, Lt}
import gleam/regexp.{type Regexp}
import gleam/result
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonNull, JsonNumber, JsonObject, JsonString,
}

pub type SchemaInfo =
  dict.Dict(jsonvalue.JsonValue, Option(ValidationNode))

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
    info: SchemaInfo,
    validation: ValidationNode,
  )
}

pub type Context {
  Context(
    current_node: JsonValue,
    current_validator: Option(ValidationNode),
    root_node: JsonValue,
    schemas: SchemaInfo,
  )
}

pub type Combination {
  AllOf
  AnyOf
  All
  Any
  OneOf
}

pub type ValidationNode {
  SimpleValidation(valid: Bool)
  RefValidation(jsonpointer: String)
  Validation(
    valid: fn(JsonValue, Schema, NodeAnnotation) ->
      #(ValidationInfo, NodeAnnotation),
  )
  PostValidation(
    valid: fn(JsonValue, Schema, NodeAnnotation) ->
      #(ValidationInfo, NodeAnnotation),
  )
  FinishLevel
  MultipleValidation(
    tests: List(ValidationNode),
    combination: Combination,
    map_error: fn(List(ValidationInfo)) -> List(ValidationInfo),
  )
  IfThenValidation(
    when: ValidationNode,
    then: Option(ValidationNode),
    orelse: Option(ValidationNode),
  )
  TypeValidation(types: dict.Dict(ValueType, ValidationNode))
  ArraySubValidation(
    prefix: Option(List(ValidationNode)),
    items: Option(ValidationNode),
    contains: Option(ValidationNode),
  )
  ObjectSubValidation(
    props: Option(Dict(String, ValidationNode)),
    pattern_props: Option(List(#(Regexp, ValidationNode))),
    additional_prop: Option(ValidationNode),
  )
  NotValidation(validation: ValidationNode)
}

pub type NodeAnnotation {
  NodeAnnotation(
    post_validation: List(ValidationNode),
    array_annotation: Option(ArrayAnnotation),
    object_annotation: Option(ObjectAnnotation),
  )
}

pub type ArrayAnnotation {
  ArrayAnnotation(
    items_index: Option(Int),
    items_all: Option(Bool),
    contains: Option(List(Int)),
    contains_all: Option(Bool),
  )
}

pub type ObjectAnnotation {
  ObjectAnnotation(prop_matches: Dict(String, Nil))
}

pub fn get_array_annotation(annotation: NodeAnnotation) -> ArrayAnnotation {
  case annotation {
    NodeAnnotation(_, Some(aa), _) -> aa
    _ -> ArrayAnnotation(None, None, None, None)
  }
}

pub fn get_object_annotation(annotation: NodeAnnotation) -> ObjectAnnotation {
  case annotation {
    NodeAnnotation(_, _, Some(oa)) -> oa
    _ -> ObjectAnnotation(dict.new())
  }
}

pub type SchemaError {
  MissingProperty(prop: String)
  InvalidProperty(prop: String, value: JsonValue)
  InvalidJson
  SchemaError
  InvalidType(got: JsonValue, wanted: Property)
  FailedValidation(value: JsonValue)
  MultipleErrors(errors: List(SchemaError))
  UnknownType(t: String)
}

pub type ValidationInfo {
  Valid
  ValidationError(desc: String)
  AlwaysFail
  InvalidKey(prop: String)
  MissingKey(prop: String)
  NoTypeYet
  IncorrectType(expect: ValueType, actual: JsonValue)
  InvalidComparison(expect: JsonValue, cmp: String, actual: JsonValue)
  InvalidMatch(match: String, actual: JsonValue)
  MultipleInfo(infos: List(ValidationInfo))
  AnyFail
  SchemaFailure
  Todo
  NotBeValid
  MatchOnlyOne
  MissingDependent(has: String, needs: String, json: JsonValue)
}

pub type ValueType {
  Number
  Integer
  String
  Array(inner_type: ValueType)
  Object(inner_type: ValueType)
  Boolean
  Null
  AnyType
  Types(List(ValueType))
  NoType
}

pub type Property {
  Property(
    name: String,
    valuetype: ValueType,
    value_check: fn(JsonValue, Context, Property) -> Result(Bool, SchemaError),
    validator_fn: Option(
      fn(JsonValue) ->
        Result(
          fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
          SchemaError,
        ),
    ),
  )
  ValidatorProperties(
    name: String,
    valuetype: ValueType,
    value_check: fn(JsonValue, Context, Property) -> Result(Bool, SchemaError),
    validator_fn: Option(
      fn(Context, fn(Context) -> Result(Context, SchemaError)) ->
        Result(
          #(
            Context,
            fn(JsonValue, Schema, NodeAnnotation) ->
              #(ValidationInfo, NodeAnnotation),
          ),
          SchemaError,
        ),
    ),
  )
}

pub fn ok_fn(_, _, _) {
  Ok(True)
}

pub fn gtzero_fn(
  v: JsonValue,
  _c: Context,
  _p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    JsonNumber(Some(i), _, _) -> {
      case int.compare(i, 0) == Gt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    JsonNumber(_, Some(f), _) -> {
      case float.compare(f, 0.0) == Gt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    _ -> Error(SchemaError)
  }
}

pub fn gtezero_fn(
  v: JsonValue,
  _c: Context,
  _p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    JsonNumber(Some(i), _, _) -> {
      case int.compare(i, 0) != Lt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    JsonNumber(_, Some(f), _) -> {
      case float.compare(f, 0.0) != Lt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    _ -> Error(SchemaError)
  }
}

pub fn valid_type_fn(
  t: JsonValue,
  c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  case t {
    JsonString(v, _) -> {
      case v {
        "null"
        | "boolean"
        | "object"
        | "array"
        | "number"
        | "string"
        | "integer" -> Ok(True)
        _ -> Error(UnknownType(v))
      }
    }
    JsonArray(v, _) -> {
      list.try_each(dict.values(v), fn(v) {
        case v {
          JsonString(_, _) -> {
            valid_type_fn(v, c, p)
          }
          _ -> Error(SchemaError)
        }
      })
      |> result.replace(True)
    }
    _ -> Error(SchemaError)
  }
}

pub fn validate_type(
  json: JsonValue,
  context: Context,
  prop: Property,
) -> Result(Option(JsonValue), SchemaError) {
  use value <- result.try(case prop.valuetype {
    Array(inner) -> {
      case json {
        JsonArray(array, _) -> {
          use _ <- result.try(case inner {
            AnyType -> Ok(Nil)
            _ -> {
              list.try_each(dict.values(array), fn(i) {
                validate_type(
                  i,
                  context,
                  Property(prop.name, inner, ok_fn, None),
                )
              })
            }
          })
          Ok(json)
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Boolean -> {
      case json {
        jsonvalue.JsonBool(_, _) -> {
          Ok(json)
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Number -> {
      case json {
        jsonvalue.JsonNumber(_, _, _) -> {
          Ok(json)
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Integer -> {
      case json {
        jsonvalue.JsonNumber(_, f, _) -> {
          case f {
            Some(f) -> {
              let i = float.truncate(f)
              case int.to_float(i) == f {
                True -> Ok(json)
                False -> Error(InvalidType(json, prop))
              }
            }
            None -> Ok(json)
          }
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Object(inner) -> {
      case json {
        JsonObject(obj, _) -> {
          use _ <- result.try(case inner {
            AnyType -> Ok(Nil)
            _ -> {
              list.try_each(dict.values(obj), fn(i) {
                validate_type(
                  i,
                  context,
                  Property(prop.name, inner, ok_fn, None),
                )
              })
            }
          })

          Ok(json)
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    String -> {
      case json {
        JsonString(_, _) -> {
          Ok(json)
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Null ->
      case json {
        JsonNull(_) -> Ok(json)
        _ -> Error(InvalidType(json, prop))
      }
    AnyType -> Ok(json)
    NoType -> todo
    Types(types) -> {
      case
        list.fold_until(types, None, fn(_, t) {
          case validate_type(json, context, swap_value_type(prop, t)) {
            Error(_) -> Continue(None)
            Ok(v) -> Stop(v)
          }
        })
      {
        None -> Error(InvalidType(json, prop))
        Some(z) -> Ok(z)
      }
    }
  })

  case prop.value_check(value, context, prop) {
    Error(_) -> Error(InvalidProperty(prop.name, json))
    Ok(False) -> Ok(None)
    Ok(True) -> Ok(Some(value))
  }
}

pub fn swap_value_type(prop: Property, t: ValueType) -> Property {
  case prop {
    ValidatorProperties(_, _, _, _) -> ValidatorProperties(..prop, valuetype: t)
    Property(_, _, _, _) -> Property(..prop, valuetype: t)
  }
}

pub fn merge_array_annotations(
  annotation: Option(ArrayAnnotation),
  to_merge: Option(ArrayAnnotation),
) -> Option(ArrayAnnotation) {
  case annotation, to_merge {
    None, None -> None
    None, merge -> merge
    merge, None -> merge
    Some(orig), Some(merge) -> {
      let ArrayAnnotation(v1, v2, v3, v4) = orig
      let ArrayAnnotation(i1, i2, i3, i4) = merge
      let r1 = case v1, i1 {
        Some(v), Some(i) -> Some(int.max(v, i))
        None, Some(i) -> Some(i)
        Some(v), None -> Some(v)
        None, None -> None
      }
      let r2 = case v2, i2 {
        Some(True), _ | _, Some(True) -> Some(True)
        None, None -> None
        _, _ -> Some(False)
      }
      let r3 = case v3, i3 {
        Some(v), Some(i) -> Some(list.flatten([v, i]) |> list.unique)
        None, Some(i) -> Some(i)
        Some(v), None -> Some(v)
        None, None -> None
      }
      let r4 = case v4, i4 {
        Some(True), _ | _, Some(True) -> Some(True)
        None, None -> None
        _, _ -> Some(False)
      }
      Some(ArrayAnnotation(r1, r2, r3, r4))
    }
  }
}

pub fn merge_object_annotation(
  annotation: Option(ObjectAnnotation),
  to_merge: Option(ObjectAnnotation),
) -> Option(ObjectAnnotation) {
  case annotation, to_merge {
    None, None -> None
    None, merge -> merge
    merge, None -> merge
    Some(orig), Some(merge) -> {
      let ObjectAnnotation(annd) = orig
      let ObjectAnnotation(d) = merge
      Some(ObjectAnnotation(dict.merge(annd, d)))
    }
  }
}

pub fn do_merge_annotations(annotations: List(NodeAnnotation)) -> NodeAnnotation {
  list.fold(annotations, NodeAnnotation([], None, None), fn(ann, i) {
    NodeAnnotation(
      list.append(ann.post_validation, i.post_validation) |> list.unique,
      merge_array_annotations(ann.array_annotation, i.array_annotation),
      merge_object_annotation(ann.object_annotation, i.object_annotation),
    )
  })
}
