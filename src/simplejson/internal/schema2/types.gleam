import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/order.{Gt, Lt}
import gleam/regexp.{type Regexp}
import gleam/result
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject}

pub type Schema {
  Schema(
    id: Option(String),
    schema_definition: Option(String),
    schema: JsonValue,
    validation: ValidationNode,
  )
}

pub type Combination {
  All
  Any
  One
}

pub type ValidationNode {
  SimpleValidation(valid: Bool)
  Validation(
    valid: fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
  )
  MultipleValidation(
    tests: List(ValidationNode),
    combination: Combination,
    map_error: fn(List(ValidationInfo)) -> List(ValidationInfo),
    isolate_annotation: Bool,
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
  NoAnnotation
  ArrayAnnotation(
    items_index: Option(Int),
    items_all: Option(Bool),
    contains: Option(List(Int)),
    contains_all: Option(Bool),
  )
  ObjectAnnotation(prop_matches: Dict(String, Nil))
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
  InvalidComparison(expect: Value, cmp: String, actual: JsonValue)
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

pub type Value {
  BooleanValue(name: String, value: Bool)
  StringValue(name: String, value: String)
  IntValue(name: String, value: Int)
  NumberValue(name: String, value: Option(Int), or_value: Option(Float))
  ObjectValue(name: String, value: Dict(String, JsonValue))
  ArrayValue(name: String, value: List(JsonValue))
  NullValue(name: String)
}

pub type Property {
  Property(
    name: String,
    valuetype: ValueType,
    value_check: fn(Value, Context, Property) -> Result(Bool, SchemaError),
    validator_fn: Option(
      fn(Value) ->
        Result(
          fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
          SchemaError,
        ),
    ),
  )
  ValidatorProperties(
    name: String,
    valuetype: ValueType,
    value_check: fn(Value, Context, Property) -> Result(Bool, SchemaError),
    validator_fn: Option(
      fn(Value, fn(JsonValue) -> Result(ValidationNode, SchemaError)) ->
        Result(
          fn(JsonValue, NodeAnnotation) -> #(ValidationInfo, NodeAnnotation),
          SchemaError,
        ),
    ),
  )
}

pub type Context {
  Context(current_node: JsonValue, root_node: JsonValue)
}

pub fn ok_fn(_, _, _) {
  Ok(True)
}

pub fn gtzero_fn(
  v: Value,
  _c: Context,
  _p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    NumberValue(_, Some(i), _) -> {
      case int.compare(i, 0) == Gt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    NumberValue(_, _, Some(f)) -> {
      case float.compare(f, 0.0) == Gt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    IntValue(_, i) -> {
      case int.compare(i, 0) == Gt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    _ -> Error(SchemaError)
  }
}

pub fn gtezero_fn(
  v: Value,
  _c: Context,
  _p: Property,
) -> Result(Bool, SchemaError) {
  case v {
    NumberValue(_, Some(i), _) -> {
      case int.compare(i, 0) != Lt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    NumberValue(_, _, Some(f)) -> {
      case float.compare(f, 0.0) != Lt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    IntValue(_, i) -> {
      case int.compare(i, 0) != Lt {
        True -> Ok(True)
        False -> Error(SchemaError)
      }
    }
    _ -> Error(SchemaError)
  }
}

pub fn valid_type_fn(
  t: Value,
  c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  case t {
    StringValue(_, v) -> {
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
    ArrayValue(_, v) -> {
      list.try_each(v, fn(v) {
        case v {
          jsonvalue.JsonString(v, _) -> {
            valid_type_fn(StringValue("", v), c, p)
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
) -> Result(Option(Value), SchemaError) {
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

          ArrayValue(prop.name, stringify.dict_to_ordered_list(array))
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Boolean -> {
      case json {
        jsonvalue.JsonBool(b, _) -> {
          BooleanValue(prop.name, b)
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Number -> {
      case json {
        jsonvalue.JsonNumber(i, f, _) -> {
          NumberValue(prop.name, i, f)
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Integer -> {
      case json {
        jsonvalue.JsonNumber(i, f, _) -> {
          case f {
            Some(f) -> {
              let i = float.truncate(f)
              case int.to_float(i) == f {
                True -> NumberValue(prop.name, Some(i), None) |> Ok
                False -> Error(InvalidType(json, prop))
              }
            }
            None -> NumberValue(prop.name, i, None) |> Ok
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

          ObjectValue(prop.name, obj)
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    String -> {
      case json {
        jsonvalue.JsonString(s, _) -> {
          StringValue(prop.name, s)
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Null -> todo
    AnyType -> Ok(map_json_to_value(prop.name, json))
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

pub fn map_json_to_value(name: String, json: JsonValue) -> Value {
  case json {
    JsonArray(array, _) ->
      ArrayValue(name, stringify.dict_to_ordered_list(array))
    JsonObject(object, _) -> ObjectValue(name, object)
    jsonvalue.JsonBool(bool, _) -> BooleanValue(name, bool)
    jsonvalue.JsonNull(_) -> NullValue(name)
    jsonvalue.JsonNumber(Some(i), _, _) -> IntValue(name, i)
    jsonvalue.JsonNumber(_, Some(f), _) -> NumberValue(name, None, Some(f))
    jsonvalue.JsonString(str, _) -> StringValue(name, str)
    _ -> {
      panic as "Invalid number construction!?!"
    }
  }
}

pub fn do_merge_annotations(annotations: List(NodeAnnotation)) -> NodeAnnotation {
  let annotations = list.filter(annotations, fn(a) { a != NoAnnotation })
  case list.first(annotations) {
    Ok(ObjectAnnotation(_)) -> {
      annotations
      |> list.fold(ObjectAnnotation(dict.new()), fn(ann, i) {
        let assert ObjectAnnotation(annd) = ann
        let assert ObjectAnnotation(d) = i
        ObjectAnnotation(dict.merge(annd, d))
      })
    }
    Ok(ArrayAnnotation(_, _, _, _)) -> {
      annotations
      |> list.fold(ArrayAnnotation(None, None, None, None), fn(ann, i) {
        let assert ArrayAnnotation(v1, v2, v3, v4) = ann
        let assert ArrayAnnotation(i1, i2, i3, i4) = i
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
        ArrayAnnotation(r1, r2, r3, r4)
      })
    }
    Ok(a) -> a
    _ -> NoAnnotation
  }
}
