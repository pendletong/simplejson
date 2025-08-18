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
}

pub type ValidationNode {
  SimpleValidation(valid: Bool)
  Validation(valid: fn(JsonValue) -> ValidationInfo)
  MultipleValidation(
    tests: List(ValidationNode),
    combination: Combination,
    map_error: fn(List(ValidationInfo)) -> List(ValidationInfo),
  )
  IfThenValidation(when: ValidationNode, then: ValidationNode)
  TypeValidation(t: ValueType)
  ArraySubValidation(
    prefix: Option(List(ValidationNode)),
    items: Option(ValidationNode),
    contains: Option(ValidationNode),
  )
  ObjectSubValidation(
    props: Option(Dict(String, ValidationNode)),
    pattern_props: Option(Dict(Regexp, ValidationNode)),
    additional_prop: Option(ValidationNode),
  )
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
  IncorrectType(expect: ValueType, actual: JsonValue)
  InvalidComparison(expect: Value, cmp: String, actual: JsonValue)
  MultipleInfo(infos: List(ValidationInfo))
  AnyFail
  SchemaFailure
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
    validation: fn(Value, Property) -> Result(Bool, SchemaError),
  )
}

pub fn ok_fn(_, _) {
  Ok(True)
}

pub fn gtzero_fn(v: Value, _p: Property) -> Result(Bool, SchemaError) {
  case v {
    NumberValue(_, Some(i), _) -> {
      Ok(int.compare(i, 0) == Gt)
    }
    NumberValue(_, _, Some(f)) -> {
      Ok(float.compare(f, 0.0) == Gt)
    }
    IntValue(_, i) -> {
      Ok(int.compare(i, 0) == Gt)
    }
    _ -> Error(SchemaError)
  }
}

pub fn gtezero_fn(v: Value, _p: Property) -> Result(Bool, SchemaError) {
  case v {
    NumberValue(_, Some(i), _) -> {
      Ok(int.compare(i, 0) != Lt)
    }
    NumberValue(_, _, Some(f)) -> {
      Ok(float.compare(f, 0.0) != Lt)
    }
    IntValue(_, i) -> {
      Ok(int.compare(i, 0) != Lt)
    }
    _ -> Error(SchemaError)
  }
}

pub fn valid_type_fn(t: Value, p: Property) -> Result(Bool, SchemaError) {
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
            valid_type_fn(StringValue("", v), p)
          }
          _ -> Error(SchemaError)
        }
      })
      |> result.replace(True)
    }
    _ -> Error(SchemaError)
  }
}

pub fn validate_types(
  json: JsonValue,
  props: List(Property),
  errors: List(SchemaError),
) -> Result(Option(Value), SchemaError) {
  case props {
    [prop, ..rest] -> {
      case validate_type(json, prop) {
        Error(err) -> {
          validate_types(json, rest, [err, ..errors])
        }
        Ok(v) -> Ok(v)
      }
    }
    [] -> {
      case errors {
        [] -> Ok(None)
        _ -> Error(MultipleErrors(errors))
      }
    }
  }
}

pub fn validate_type(
  json: JsonValue,
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
                validate_type(i, Property(prop.name, inner, ok_fn))
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
        jsonvalue.JsonNumber(i, f, _, _) -> {
          NumberValue(prop.name, i, f)
          |> Ok
        }
        _ -> Error(InvalidType(json, prop))
      }
    }
    Integer -> {
      case json {
        jsonvalue.JsonNumber(i, f, _, _) -> {
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
                validate_type(i, Property(prop.name, inner, ok_fn))
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
    AnyType -> todo
    NoType -> todo
    Types(types) -> {
      case
        list.fold_until(types, None, fn(_, t) {
          case validate_type(json, Property(prop.name, t, prop.validation)) {
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

  case prop.validation(value, prop) {
    Error(e) -> Error(e)
    Ok(False) -> Ok(None)
    Ok(True) -> Ok(Some(value))
  }
}
