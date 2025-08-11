import gleam/bool
import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/string
import simplejson/internal/stringify

import gleam/option.{type Option, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/yielder
import simplejson/internal/jsonpath.{
  type Comparable, type CompareOp, type JsonPath, type Literal,
  type LogicalExpression, type Segment, type Selector, type SingularSegment,
  type TypeValue, Boolean, Child, Descendant, Filter, Index, Name, Nothing, Null,
  Number, SingleIndex, SingleName, Slice, String, ValueType,
}
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub fn query(json: JsonValue, path: JsonPath, absroot: JsonValue) -> JsonValue {
  query_to_list(json, path, absroot)
  |> parser.list_to_indexed_dict
  |> JsonArray
  |> echo
}

fn query_to_list(
  json: JsonValue,
  path: JsonPath,
  absroot: JsonValue,
) -> List(JsonValue) {
  list.fold(path, [json], fn(acc, segment) { do_query(acc, segment, absroot) })
}

fn do_query(
  json: List(JsonValue),
  segment: Segment,
  absroot: JsonValue,
) -> List(JsonValue) {
  list.fold(json, [], fn(acc, j) {
    let results = case segment {
      Child(selectors) -> process_selectors(selectors, [j], absroot)
      Descendant(selectors) ->
        process_selectors(selectors, get_descendants([j], j) |> echo, absroot)
    }
    list.append(acc, results)
  })
}

fn process_selectors(
  selectors: List(Selector),
  nodes: List(JsonValue),
  absroot: JsonValue,
) -> List(JsonValue) {
  list.fold(nodes, [], fn(arr, node) {
    let found = do_checks(node, selectors, absroot)

    list.append(arr, found)
  })
}

fn get_descendants(list: List(JsonValue), json: JsonValue) -> List(JsonValue) {
  case json {
    JsonObject(d) -> {
      let new_list = dict.values(d)
      list.fold(new_list, list.append(list, new_list), get_descendants)
    }
    JsonArray(d) -> {
      let new_list = dict.values(d)
      list.fold(new_list, list.append(list, new_list), get_descendants)
    }
    _ -> list
  }
}

fn do_checks(
  json: JsonValue,
  selectors: List(Selector),
  absroot: JsonValue,
) -> List(JsonValue) {
  list.fold(selectors, [], fn(list, selector) {
    let found = do_selector(json, selector, absroot) |> echo

    list.append(list, found)
  })
}

fn do_selector(
  json: JsonValue,
  selector: Selector,
  absroot: JsonValue,
) -> List(JsonValue) {
  case selector {
    Filter(expr:) -> do_filter(json, expr, absroot)
    Index(i:) -> do_index(json, i)
    Name(name:) -> do_name(json, name)
    Slice(start:, end:, step:) -> {
      do_slice(json, start, end, step)
    }
    jsonpath.Wildcard -> do_wildcard(json)
  }
}

fn do_filter(
  json: JsonValue,
  expr: LogicalExpression,
  absroot: JsonValue,
) -> List(JsonValue) {
  "filtering" |> echo
  let l = case json {
    JsonArray(d) -> {
      stringify.dict_to_ordered_list(d)
    }
    JsonObject(d) -> dict.values(d)
    _ -> []
  }
  use <- bool.guard(when: l == [], return: [])
  list.fold(l, [], fn(res, json) {
    case
      list.fold_until(expr.or.ands, False, fn(_, and_expr) {
        case
          list.fold_until(and_expr.and, True, fn(_, expr) {
            case expr {
              jsonpath.Comparison(cmp1:, cmp2:, cmpop:) -> {
                case do_comparison(json, cmp1, cmp2, cmpop, absroot) {
                  True -> Continue(True)
                  False -> Stop(False)
                }
              }
              jsonpath.Paren(expr:, not:) -> todo
              jsonpath.Test(expr:, not:) -> {
                case expr {
                  jsonpath.FilterQuery(fq) -> {
                    let #(root, path) = case fq {
                      jsonpath.Relative(path:) -> #(json, path)
                      jsonpath.Root(path:) -> #(absroot, path)
                    }
                    case list.is_empty(query_to_list(root, path, absroot)) {
                      True -> Stop(False)
                      False -> Continue(True)
                    }
                  }
                  jsonpath.FunctionExpr(_) -> todo
                }
              }
            }
          })
        {
          True -> Stop(True)
          False -> Continue(False)
        }
      })
    {
      True -> [json, ..res]
      False -> res
    }
  })
  |> echo
  |> list.reverse
}

fn do_comparison(
  root: JsonValue,
  cmp1: Comparable,
  cmp2: Comparable,
  op: CompareOp,
  absroot: JsonValue,
) -> Bool {
  let cmp1 = get_comparable(root, cmp1, absroot)
  let cmp2 = get_comparable(root, cmp2, absroot)
  compare_types(cmp1, cmp2, op)
}

fn compare_types(tv1: TypeValue, tv2: TypeValue, op: CompareOp) -> Bool {
  case tv1, tv2 {
    ValueType(Number(n1neg, n1int, n1frac, n1exp)),
      ValueType(Number(n2neg, n2int, n2frac, n2exp))
    ->
      compare_numbers(
        #(n1neg, n1int, n1frac, n1exp),
        #(n2neg, n2int, n2frac, n2exp),
        op,
      )
    ValueType(String(s1)), ValueType(String(s2)) -> compare_strings(s1, s2, op)

    _, _ -> False
  }
}

fn compare_numbers(
  n1: #(Bool, Int, Option(Int), Option(Int)),
  n2: #(Bool, Int, Option(Int), Option(Int)),
  op: CompareOp,
) -> Bool {
  todo
}

fn compare_strings(s1: String, s2: String, op: CompareOp) -> Bool {
  let order = string.compare(s1, s2)
  case op {
    jsonpath.Eq -> order == Eq
    jsonpath.Gt -> order == Gt
    jsonpath.Gte -> order == Gt || order == Eq
    jsonpath.Lt -> order == Lt
    jsonpath.Lte -> order == Lt || order == Eq
    jsonpath.NotEq -> order != Eq
  }
}

fn get_comparable(
  root: JsonValue,
  cmp: Comparable,
  absroot: JsonValue,
) -> TypeValue {
  case cmp {
    jsonpath.FunctionExprCmp(_) -> todo
    jsonpath.Literal(l) -> ValueType(l)
    jsonpath.QueryCmp(sq) -> {
      let #(root, sq) = case sq {
        jsonpath.AbsQuery(sq) -> #(absroot, sq)
        jsonpath.RelQuery(sq) -> #(root, sq)
      }
      let jp = map_singular_query_to_query(sq)
      case query(root, jp, absroot) |> echo as "query" {
        JsonArray(arr) -> {
          case dict.size(arr) {
            1 -> {
              let assert Ok(v) = dict.get(arr, 0)
              ValueType(jsonvalue_to_literal(v))
            }
            0 -> {
              ValueType(Nothing)
            }
            _ -> panic
          }
        }
        _ -> panic
      }
    }
  }
}

fn jsonvalue_to_literal(jv: JsonValue) -> Literal {
  case jv {
    JsonArray(_) -> Nothing
    JsonObject(_) -> Nothing
    JsonBool(bool:) -> Boolean(bool)
    JsonNull -> Null
    JsonNumber(int:, float:, original:) -> todo
    JsonString(str:) -> String(str)
  }
}

fn map_singular_query_to_query(sq: List(SingularSegment)) -> JsonPath {
  list.map(sq, fn(segment) {
    case segment {
      SingleIndex(i) -> Child([Index(i)])
      SingleName(n) -> Child([Name(n)])
    }
  })
}

fn do_slice(
  json: JsonValue,
  start: Option(Int),
  end: Option(Int),
  step: Option(Int),
) -> List(JsonValue) {
  case json {
    JsonArray(d) -> {
      use <- bool.guard(when: step == Some(0), return: [])
      let len = dict.size(d)
      let step = option.unwrap(step, 1)
      let start =
        option.lazy_unwrap(start, fn() {
          case step >= 0 {
            True -> 0
            False -> len - 1
          }
        })
      let end =
        option.lazy_unwrap(end, fn() {
          case step >= 0 {
            True -> len
            False -> -len - 1
          }
        })
      let #(start, end) = get_bounds(start, end, step, len)

      let yielder =
        yielder.unfold(start, fn(acc) {
          case int.compare(step, 0) {
            Gt -> {
              case acc < end {
                True -> yielder.Next(acc, acc + step)
                False -> yielder.Done
              }
            }
            Lt -> {
              case acc > end {
                True -> yielder.Next(acc, acc + step)
                False -> yielder.Done
              }
            }
            Eq -> panic
          }
        })

      let l =
        yielder.fold(yielder, [], fn(l, index) {
          case dict.get(d, index) {
            Error(_) -> l
            Ok(v) -> [v, ..l]
          }
        })

      list.reverse(l)
    }
    _ -> []
  }
}

fn get_bounds(start: Int, end: Int, step: Int, len: Int) -> #(Int, Int) {
  let start = normalise(start, len)
  let end = normalise(end, len)

  case step >= 0 {
    True -> {
      let lower = int.min(int.max(start, 0), len)
      let upper = int.min(int.max(end, 0), len)
      #(lower, upper)
    }
    False -> {
      let upper = int.min(int.max(start, -1), len - 1)
      let lower = int.min(int.max(end, -1), len - 1)
      #(upper, lower)
    }
  }
}

fn normalise(i: Int, len: Int) -> Int {
  case i >= 0 {
    True -> i
    False -> len + i
  }
}

fn do_index(json: JsonValue, index: Int) -> List(JsonValue) {
  case json {
    JsonArray(d) -> {
      case index >= 0 {
        True -> {
          case dict.get(d, index) {
            Ok(j) -> [j]
            _ -> []
          }
        }
        False -> {
          let index = dict.size(d) + index
          case index < 0 {
            True -> []
            False -> {
              case dict.get(d, index) {
                Ok(j) -> [j]
                _ -> []
              }
            }
          }
        }
      }
    }
    _ -> []
  }
}

fn do_wildcard(json: JsonValue) -> List(JsonValue) {
  case json {
    JsonArray(d) -> stringify.dict_to_ordered_list(d) |> echo
    JsonObject(d) -> dict.values(d)
    _ -> []
  }
}

fn do_name(json: JsonValue, name: String) -> List(JsonValue) {
  case json {
    JsonObject(d) -> {
      case dict.get(d, name) {
        Ok(v) -> [v]
        _ -> []
      }
    }
    _ -> []
  }
}
