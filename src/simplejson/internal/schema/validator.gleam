import gleam/dict.{type Dict}
import gleam/io
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/result
import simplejson
import simplejson/internal/schema/properties/number.{validate_number}
import simplejson/internal/schema/properties/string.{validate_string}
import simplejson/internal/schema/types.{
  type Combination, type InvalidEntry, type Schema, type ValidationNode,
  ArrayNode, BooleanNode, EnumNode, FalseSchema, InvalidDataType, InvalidJson,
  MultiNode, NotMatchEnum, NullNode, NumberNode, Schema, SimpleValidation,
  StringNode,
}
import simplejson/internal/stringify
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonBool, JsonNull}

pub fn do_validate(
  json: String,
  schema: Schema,
) -> Result(Bool, List(InvalidEntry)) {
  case simplejson.parse(json) {
    Error(err) -> Error([InvalidJson(err)])
    Ok(json) -> {
      validate_node(json, schema.validation)
    }
  }
}

fn validate_node(
  node: JsonValue,
  with validation_node: ValidationNode,
) -> Result(Bool, List(InvalidEntry)) {
  case validation_node {
    EnumNode(values) -> {
      validate_enum(node, values)
    }
    StringNode(props) -> {
      validate_string(node, props)
    }
    NumberNode(props) -> {
      validate_number(node, props)
    }
    ArrayNode(props, items, tuple, _root) -> {
      validate_array(node, items, tuple, props)
    }
    BooleanNode -> {
      validate_boolean(node)
    }
    NullNode -> {
      validate_null(node)
    }
    SimpleValidation(True) -> {
      Ok(True)
    }
    SimpleValidation(False) -> {
      Error([FalseSchema])
    }
    MultiNode(v_nodes, comb) -> {
      validate_multinode(node, v_nodes, comb)
    }
  }
}

pub fn validate_array(
  node: JsonValue,
  items: Option(ValidationNode),
  prefix_items: Option(List(ValidationNode)),
  properties: List(fn(JsonValue) -> Option(InvalidEntry)),
) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonArray(_, l) -> {
      use remaining_nodes <- result.try(case prefix_items {
        Some(val_nodes) -> {
          use rem_nodes <- result.try(
            validate_items(stringify.dict_to_ordered_list(l), val_nodes, []),
          )
          Ok(rem_nodes)
        }
        None -> Ok(stringify.dict_to_ordered_list(l))
      })
      use _ <- result.try(case items {
        Some(vn) -> {
          list.try_each(remaining_nodes, fn(n) { validate_node(n, vn) })
          |> result.replace(True)
        }
        None -> Ok(True)
      })

      let result =
        list.try_each(properties, fn(validate) {
          case validate(node) {
            Some(e) -> Error(e)
            None -> Ok(Nil)
          }
        })
      case result {
        Ok(Nil) -> Ok(True)
        Error(err) -> Error([err])
      }
    }
    _ -> Error([InvalidDataType(node)])
  }
}

fn validate_items(
  json: List(JsonValue),
  validators: List(ValidationNode),
  errors: List(InvalidEntry),
) -> Result(List(JsonValue), List(InvalidEntry)) {
  case json {
    [] -> {
      case errors {
        [] -> Ok([])
        _ -> Error(errors)
      }
    }
    [node, ..rest] -> {
      case validators {
        [] -> {
          case errors {
            [] -> Ok(json)
            _ -> Error(errors)
          }
        }
        [v, ..v_rest] -> {
          let res = validate_node(node, v)
          let errors = case res {
            Error(err) -> list.append(err, errors)
            _ -> errors
          }
          validate_items(rest, v_rest, errors)
        }
      }
    }
  }
}

fn validate_enum(
  node: JsonValue,
  values: List(JsonValue),
) -> Result(Bool, List(InvalidEntry)) {
  #("validate", node, values) |> echo
  case list.find(values, fn(v) { v == node }) {
    Ok(_) -> Ok(True)
    Error(_) -> Error([NotMatchEnum(node)])
  }
}

fn validate_all(node: JsonValue, validators: List(ValidationNode)) {
  list.fold(validators, [], fn(errors, v_node) {
    case validate_node(node, v_node) {
      Ok(_) -> errors
      Error(err) -> list.append(err, errors)
    }
  })
}

fn validate_any(node: JsonValue, validators: List(ValidationNode)) {
  list.fold_until(validators, [], fn(errors, v_node) {
    case validate_node(node, v_node) {
      Ok(_) -> Stop([])
      Error(err) -> Continue(list.append(err, errors))
    }
  })
}

fn validate_multinode(
  node: JsonValue,
  validators: List(ValidationNode),
  combination: Combination,
) -> Result(Bool, List(InvalidEntry)) {
  let comp = case combination {
    types.All -> validate_all
    types.Any -> validate_any
    types.None -> todo
    types.One -> todo
  }
  case comp(node, validators) {
    [] -> Ok(True)
    errors -> {
      // Filtering the invalid data types should remove
      // any nodes that type didn't match and keep the node type
      // that matched and its error
      let errors =
        list.filter(errors, fn(err) {
          case err {
            InvalidDataType(_) -> False
            _ -> True
          }
        })

      // If there are no errors then the issue must be
      // data type matching so return that error
      let errors = case errors {
        [] -> [InvalidDataType(node)]
        _ -> errors
      }
      Error(errors)
    }
  }
}

fn validate_boolean(node: JsonValue) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonBool(_, _) -> Ok(True)
    _ -> Error([InvalidDataType(node)])
  }
}

fn validate_null(node: JsonValue) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonNull(_) -> Ok(True)
    _ -> Error([InvalidDataType(node)])
  }
}
