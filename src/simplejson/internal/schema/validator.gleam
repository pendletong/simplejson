import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/result
import simplejson
import simplejson/internal/schema/properties/number.{validate_number}
import simplejson/internal/schema/properties/string.{validate_string}
import simplejson/internal/schema/types.{
  type Combination, type InvalidEntry, type Schema, type ValidationNode,
  ArrayNode, BooleanNode, ContainsNode, EnumNode, FailedProperty, FalseSchema,
  IntProperty, InvalidDataType, InvalidJson, MultiNode, NotMatchEnum, NullNode,
  NumberNode, PropertiesNode, Schema, SimpleValidation, StringNode,
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
    PropertiesNode(props) -> {
      validate_properties(props, node)
    }
    StringNode -> {
      validate_string(node)
    }
    NumberNode -> {
      validate_number(node)
    }
    ArrayNode(items, tuple) -> {
      validate_array(node, items, tuple)
    }
    ContainsNode(v_node, min, max) -> {
      let res = validate_array_contains(node, v_node, min, max)
      case res {
        [] -> Ok(True)
        _ -> Error(res)
      }
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

pub fn validate_properties(
  properties: List(fn(JsonValue) -> Option(InvalidEntry)),
  node: JsonValue,
) -> Result(Bool, List(InvalidEntry)) {
  let result =
    list.filter_map(properties, fn(validate) {
      case validate(node) {
        Some(e) -> Ok(e)
        None -> Error(Nil)
      }
    })
  case result {
    [] -> Ok(True)
    err -> Error(err)
  }
}

fn validate_array_contains(
  node: JsonValue,
  v_node: ValidationNode,
  min: Option(Int),
  max: Option(Int),
) -> List(InvalidEntry) {
  case node {
    JsonArray(_, l) -> {
      let res =
        list.fold(l, #(0, []), fn(acc, node) {
          case validate_node(node, v_node) {
            Ok(_) -> {
              #(acc.0 + 1, acc.1)
            }
            Error(err) -> {
              #(acc.0, list.append(err, acc.1))
            }
          }
        })
      let min_errs = case min {
        Some(min_val) -> {
          case res.0 >= min_val {
            True -> []
            False -> [FailedProperty(IntProperty("minContains", min_val), node)]
          }
        }
        _ -> []
      }
      let max_errs = case max {
        Some(max_val) -> {
          case res.0 <= max_val {
            True -> []
            False -> [FailedProperty(IntProperty("maxContains", max_val), node)]
          }
        }
        _ -> []
      }
      res.1
      |> list.append(min_errs)
      |> list.append(max_errs)
    }
    _ -> [InvalidDataType(node)]
  }
}

pub fn validate_array(
  node: JsonValue,
  items: Option(ValidationNode),
  prefix_items: Option(List(ValidationNode)),
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
      case items {
        Some(vn) -> {
          list.try_each(remaining_nodes, fn(n) { validate_node(n, vn) })
          |> result.replace(True)
        }
        None -> Ok(True)
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
  case list.find(values, fn(v) { v == node }) {
    Ok(_) -> Ok(True)
    Error(_) -> Error([NotMatchEnum(node)])
  }
}

fn validate_all(node: JsonValue, validators: List(ValidationNode)) {
  list.fold(validators, [], fn(errors, v_node) {
    case validate_node(node, v_node) {
      Ok(_) -> errors
      Error(err) -> {
        list.append(errors, err)
      }
    }
  })
}

fn validate_all_break(node: JsonValue, validators: List(ValidationNode)) {
  case validators {
    [vn, ..rest] -> {
      case validate_node(node, vn) {
        Ok(_) -> validate_all(node, rest)
        Error(err) -> err
      }
    }
    [] -> []
  }
}

fn validate_any(node: JsonValue, validators: List(ValidationNode)) {
  list.fold_until(validators, [], fn(errors, v_node) {
    case validate_node(node, v_node) {
      Ok(_) -> Stop([])
      Error(err) -> Continue(list.append(errors, err))
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
    types.AllBreakAfterFirst -> validate_all_break
    types.None -> todo
    types.One -> todo
  }
  case comp(node, validators) {
    [] -> Ok(True)
    errors -> {
      Error(list.unique(errors))
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
