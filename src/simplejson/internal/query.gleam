import bigdecimal.{type BigDecimal}
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/regexp.{type Regexp}
import gleam/string
import simplejson/internal/stringify

import gleam/option.{type Option, None, Some}
import gleam/order.{type Order, Eq, Gt, Lt}
import gleam/yielder
import simplejson/internal/jsonpath.{
  type Comparable, type CompareOp, type Function, type JsonPath, type Literal,
  type LogicalExpression, type Segment, type Selector, type SingularSegment,
  type TypeValue, Array, Boolean, Child, Descendant, Filter, Function, Index,
  LogicalType, Name, NodesType, Nothing, Null, Number, Object, SingleIndex,
  SingleName, Slice, String, ValueType,
}
import simplejson/internal/parser
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub fn query(json: JsonValue, path: JsonPath, absroot: JsonValue) -> JsonValue {
  query_to_list(json, path, absroot)
  |> parser.list_to_indexed_dict
  |> JsonArray(None)
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
        process_selectors(selectors, get_descendants([j], j), absroot)
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
    JsonObject(d, _) -> {
      let new_list = dict.values(d)
      list.fold(new_list, list.append(list, new_list), get_descendants)
    }
    JsonArray(d, _) -> {
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
    let found = do_selector(json, selector, absroot)

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
  let l = case json {
    JsonArray(d, _) -> {
      stringify.dict_to_ordered_list(d)
    }
    JsonObject(d, _) -> dict.values(d)
    _ -> []
  }
  use <- bool.guard(when: l == [], return: [])
  list.fold(l, [], fn(res, json) {
    case do_logical_expr(json, expr, absroot) {
      True -> [json, ..res]
      False -> res
    }
  })
  |> list.reverse
}

fn do_logical_expr(
  json: JsonValue,
  expr: LogicalExpression,
  absroot: JsonValue,
) -> Bool {
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
          jsonpath.Paren(expr:, not:) -> {
            let cmp = do_logical_expr(json, expr, absroot)
            let cmp = case not {
              False -> cmp
              True -> !cmp
            }
            case cmp {
              True -> Continue(True)
              False -> Stop(False)
            }
          }
          jsonpath.Test(expr:, not:) -> {
            case expr {
              jsonpath.FilterQuery(fq) -> {
                let #(root, path) = case fq {
                  jsonpath.Relative(path:) -> #(json, path)
                  jsonpath.Root(path:) -> #(absroot, path)
                }
                case list.is_empty(query_to_list(root, path, absroot)), not {
                  True, False -> Stop(False)
                  False, False -> Continue(True)
                  False, True -> Stop(False)
                  True, True -> Continue(True)
                }
              }
              jsonpath.FunctionExpr(fe) -> {
                case run_function(json, fe, absroot) {
                  ValueType(_) -> panic
                  LogicalType(cmp) -> {
                    let cmp = case not {
                      False -> cmp
                      True -> !cmp
                    }
                    case cmp {
                      True -> Continue(True)
                      False -> Stop(False)
                    }
                  }
                  NodesType(_) -> panic
                }
              }
            }
          }
        }
      })
    {
      True -> Stop(True)
      False -> Continue(False)
    }
  })
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
    ValueType(Number(n1)), ValueType(Number(n2)) -> compare_numbers(n1, n2, op)
    ValueType(String(s1)), ValueType(String(s2)) -> compare_strings(s1, s2, op)
    ValueType(Null), ValueType(Null) -> {
      compare_items(Eq, op)
    }
    ValueType(Boolean(b1)), ValueType(Boolean(b2)) -> {
      case b1 == b2 {
        True -> op == jsonpath.Eq || op == jsonpath.Gte || op == jsonpath.Lte
        False -> op == jsonpath.NotEq
      }
    }
    ValueType(Array(d1)), ValueType(Array(d2)) -> d1 == d2
    ValueType(Object(d1)), ValueType(Object(d2)) -> d1 == d2
    ValueType(Nothing), ValueType(Nothing) -> True
    _, _ -> {
      case op {
        jsonpath.NotEq -> True
        _ -> False
      }
    }
  }
}

fn compare_numbers(n1: BigDecimal, n2: BigDecimal, op: CompareOp) -> Bool {
  let order = bigdecimal.compare(n1, n2)
  compare_items(order, op)
}

fn compare_strings(s1: String, s2: String, op: CompareOp) -> Bool {
  let order = string.compare(s1, s2)
  compare_items(order, op)
}

fn compare_items(order: Order, op: CompareOp) -> Bool {
  case op {
    jsonpath.Eq -> order == Eq
    jsonpath.Gt -> order == Gt
    jsonpath.Gte -> order == Gt || order == Eq
    jsonpath.Lt -> order == Lt
    jsonpath.Lte -> order == Lt || order == Eq
    jsonpath.NotEq -> order != Eq
  }
}

fn run_function(root: JsonValue, f: Function, absroot: JsonValue) -> TypeValue {
  let Function(deffn, args) = f
  let args =
    list.map(args, fn(a) {
      case a {
        jsonpath.FunctionArg(fa) -> run_function(root, fa, absroot)
        jsonpath.LiteralArg(l) -> ValueType(l)
        jsonpath.LogicalArg(la) ->
          LogicalType(do_logical_expr(root, la, absroot))
        jsonpath.QueryArg(qa) -> {
          let #(root, qa) = case qa {
            jsonpath.Root(sq) -> #(absroot, sq)
            jsonpath.Relative(sq) -> #(root, sq)
          }
          query_to_list(root, qa, absroot)
          |> NodesType
        }
        jsonpath.QuerySingularArg(qa) -> {
          let #(root, qa) = case qa {
            jsonpath.Root(sq) -> #(absroot, sq)
            jsonpath.Relative(sq) -> #(root, sq)
          }
          case query_to_list(root, qa, absroot) {
            [v] -> NodesType([v])
            _ -> ValueType(Nothing)
          }
        }
      }
    })
  case deffn {
    jsonpath.Count -> {
      case args {
        [arg] -> do_fn_count(arg)
        _ -> panic as "Invalid Length arguments"
      }
    }
    jsonpath.Length -> {
      case args {
        [arg] -> do_fn_length(arg)
        _ -> panic as "Invalid Length arguments"
      }
    }
    jsonpath.Match -> {
      case args {
        [a1, a2] -> do_fn_match(a1, a2)
        _ -> panic as "Invalid Match arguments"
      }
    }
    jsonpath.Search -> {
      case args {
        [a1, a2] -> do_fn_search(a1, a2)
        _ -> panic as "Invalid Search arguments"
      }
    }
    jsonpath.Unknown(_) -> ValueType(Nothing)
    jsonpath.ValueOf -> {
      case args {
        [arg] -> do_fn_value(arg)
        _ -> panic as "Invalid Length arguments"
      }
    }
  }
}

fn fix_regexp(str: String) -> Regexp {
  // This needs to follow I-Regexp (rfc9485) but for the time being use standard
  // regexp
  case regexp.from_string(do_fix_regexp(str, "", False)) {
    Error(_) -> panic as "Invalid Regexp"
    Ok(r) -> r
  }
}

fn do_fix_regexp(str: String, new_regexp: String, in_class: Bool) -> String {
  case str {
    "\\[" <> rest -> do_fix_regexp(rest, new_regexp <> "\\[", in_class)
    "[" <> rest -> do_fix_regexp(rest, new_regexp <> "[", True)
    "\\]" <> rest -> do_fix_regexp(rest, new_regexp <> "\\]", in_class)
    "]" <> rest -> do_fix_regexp(rest, new_regexp <> "]", False)
    "\\\\" <> rest -> do_fix_regexp(rest, new_regexp <> "\\\\", in_class)
    "\\." <> rest -> do_fix_regexp(rest, new_regexp <> "\\.", in_class)
    "." <> rest -> {
      case in_class {
        True -> do_fix_regexp(rest, new_regexp <> ".", in_class)
        False -> do_fix_regexp(rest, new_regexp <> "[^\\n\\r]", in_class)
      }
    }
    "" -> new_regexp
    x -> {
      case string.pop_grapheme(x) {
        Error(_) -> new_regexp
        Ok(#(char, rest)) -> do_fix_regexp(rest, new_regexp <> char, in_class)
      }
    }
  }
}

fn do_fn_match(arg1: TypeValue, arg2: TypeValue) -> TypeValue {
  case arg1, arg2 {
    ValueType(String(s)), ValueType(String(s2)) -> {
      // Regexp...
      LogicalType(regexp.check(fix_regexp("^" <> s2 <> "$"), s))
    }
    NodesType([v1]), NodesType([v2]) -> {
      do_fn_match(
        ValueType(jsonvalue_to_literal(v1)),
        ValueType(jsonvalue_to_literal(v2)),
      )
    }
    NodesType([v]), _ -> {
      do_fn_match(ValueType(jsonvalue_to_literal(v)), arg2)
    }
    _, NodesType([v]) -> {
      do_fn_match(arg1, ValueType(jsonvalue_to_literal(v)))
    }
    _, _ -> LogicalType(False)
  }
}

fn do_fn_search(arg1: TypeValue, arg2: TypeValue) -> TypeValue {
  case arg1, arg2 {
    ValueType(String(s)), ValueType(String(s2)) -> {
      // Regexp...
      LogicalType(regexp.check(fix_regexp(s2), s))
    }
    NodesType([v1]), NodesType([v2]) -> {
      do_fn_search(
        ValueType(jsonvalue_to_literal(v1)),
        ValueType(jsonvalue_to_literal(v2)),
      )
    }
    NodesType([v]), _ -> {
      do_fn_search(ValueType(jsonvalue_to_literal(v)), arg2)
    }
    _, NodesType([v]) -> {
      do_fn_search(arg1, ValueType(jsonvalue_to_literal(v)))
    }
    _, _ -> LogicalType(False)
  }
}

fn do_fn_value(arg: TypeValue) -> TypeValue {
  case arg {
    ValueType(_) -> ValueType(Nothing)
    LogicalType(_) -> ValueType(Nothing)
    NodesType(l) -> {
      case l {
        [v] -> {
          ValueType(jsonvalue_to_literal(v))
        }
        _ -> ValueType(Nothing)
      }
    }
  }
}

fn do_fn_count(arg: TypeValue) -> TypeValue {
  case arg {
    ValueType(_) -> ValueType(Nothing)
    LogicalType(_) -> ValueType(Nothing)
    NodesType(l) ->
      list.length(l)
      |> int.to_float
      |> bigdecimal.from_float
      |> Number
      |> ValueType
  }
}

fn do_fn_length(arg: TypeValue) -> TypeValue {
  case arg {
    ValueType(String(s)) ->
      string.length(s)
      |> int.to_float
      |> bigdecimal.from_float
      |> Number
      |> ValueType

    ValueType(Array(a)) ->
      dict.size(a)
      |> int.to_float
      |> bigdecimal.from_float
      |> Number
      |> ValueType
    ValueType(Boolean(_)) -> ValueType(Nothing)
    ValueType(Nothing) -> ValueType(Nothing)
    ValueType(Null) -> ValueType(Nothing)
    ValueType(Number(_)) -> ValueType(Nothing)
    ValueType(Object(o)) ->
      dict.size(o)
      |> int.to_float
      |> bigdecimal.from_float
      |> Number
      |> ValueType
    LogicalType(_) -> ValueType(Nothing)
    NodesType([l]) -> do_fn_length(ValueType(jsonvalue_to_literal(l)))
    NodesType(_) -> ValueType(Nothing)
  }
}

fn get_comparable(
  root: JsonValue,
  cmp: Comparable,
  absroot: JsonValue,
) -> TypeValue {
  case cmp {
    jsonpath.FunctionExprCmp(f) -> run_function(root, f, absroot)
    jsonpath.Literal(l) -> ValueType(l)
    jsonpath.QueryCmp(sq) -> {
      let #(root, sq) = case sq {
        jsonpath.AbsQuery(sq) -> #(absroot, sq)
        jsonpath.RelQuery(sq) -> #(root, sq)
      }
      let jp = map_singular_query_to_query(sq)
      case query_to_list(root, jp, absroot) {
        [v] -> {
          ValueType(jsonvalue_to_literal(v))
        }
        [] -> {
          ValueType(Nothing)
        }
        _ -> panic
      }
    }
  }
}

fn jsonvalue_to_literal(jv: JsonValue) -> Literal {
  case jv {
    JsonArray(arr, _) -> Array(arr)
    JsonObject(obj, _) -> Object(obj)
    JsonBool(_, bool:) -> Boolean(bool)
    JsonNull(_) -> Null
    JsonNumber(_, int: Some(i), float: _, original: _) -> {
      let assert Ok(bd) = bigdecimal.from_string(int.to_string(i))
      Number(bd)
    }
    JsonNumber(_, int: _, float: _, original: Some(s)) -> {
      let assert Ok(#(n, _)) = jsonpath.parse_literal_number(s)
      n
    }
    JsonNumber(_, int: _, float: Some(f), original: _) -> {
      Number(bigdecimal.from_float(f))
    }

    JsonString(_, str:) -> String(str)
    JsonNumber(_, int: None, float: None, original: None) -> panic
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
    JsonArray(d, _) -> {
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
    JsonArray(d, _) -> {
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
    JsonArray(d, _) -> stringify.dict_to_ordered_list(d)
    JsonObject(d, _) -> dict.values(d)
    _ -> []
  }
}

fn do_name(json: JsonValue, name: String) -> List(JsonValue) {
  case json {
    JsonObject(d, _) -> {
      case dict.get(d, name) {
        Ok(v) -> [v]
        _ -> []
      }
    }
    _ -> []
  }
}
