import gleam/dict.{type Dict}
import gleam/list.{Continue, Stop}
import simplejson/internal/parser
import simplejson/internal/schema/properties/array.{validate_array}
import simplejson/internal/schema/properties/number.{validate_number}
import simplejson/internal/schema/properties/string.{validate_string}
import simplejson/internal/schema/types.{
  type Combination, type InvalidEntry, type Schema, type ValidationNode,
  ArrayNode, BooleanNode, FalseSchema, InvalidDataType, InvalidJson, MultiNode,
  NullNode, NumberNode, Schema, SimpleValidation, StringNode,
}
import simplejson/jsonvalue.{type JsonValue, JsonBool, JsonNull}

pub fn do_validate(json: String, schema: Schema) -> #(Bool, List(InvalidEntry)) {
  case parser.parse(json) {
    Error(err) -> #(False, [InvalidJson(err)])
    Ok(json) -> {
      validate_node(json, schema.validation, schema.sub_schema)
    }
  }
}

fn validate_node(
  node: JsonValue,
  with validation_node: ValidationNode,
  and sub_schema: Dict(String, Schema),
) -> #(Bool, List(InvalidEntry)) {
  case validation_node {
    StringNode(props) -> {
      validate_string(node, props)
    }
    NumberNode(props) -> {
      validate_number(node, props)
    }
    ArrayNode(props, _validators, _root) -> {
      validate_array(node, props)
    }
    BooleanNode -> {
      validate_boolean(node)
    }
    NullNode -> {
      validate_null(node)
    }
    SimpleValidation(True) -> {
      #(True, [])
    }
    SimpleValidation(False) -> {
      #(False, [FalseSchema])
    }
    MultiNode(v_nodes, comb) -> {
      validate_multinode(node, v_nodes, comb, sub_schema)
    }
  }
}

fn validate_multinode(
  node: JsonValue,
  validators: List(ValidationNode),
  _combination: Combination,
  sub_schema: Dict(String, Schema),
) -> #(Bool, List(InvalidEntry)) {
  case
    list.fold_until(validators, [], fn(errors, v_node) {
      case validate_node(node, v_node, sub_schema) {
        #(True, _) -> Stop([])
        #(False, err) -> Continue(list.append(err, errors))
      }
    })
  {
    [] -> #(True, [])
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
      #(False, errors)
    }
  }
}

fn validate_boolean(node: JsonValue) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonBool(_, _) -> #(True, [])
    _ -> #(False, [InvalidDataType(node)])
  }
}

fn validate_null(node: JsonValue) -> #(Bool, List(InvalidEntry)) {
  case node {
    JsonNull(_) -> #(True, [])
    _ -> #(False, [InvalidDataType(node)])
  }
}
