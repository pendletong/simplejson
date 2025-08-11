import gleam/bool
import gleam/dict
import gleam/int
import gleam/list

import gleam/option.{type Option, Some}
import gleam/order
import gleam/result
import gleam/yielder
import simplejson/internal/jsonpath.{
  type JsonPath, type Segment, type Selector, Child, Descendant,
}
import simplejson/internal/parser
import simplejson/jsonvalue.{type JsonValue, JsonArray, JsonObject}

pub type QueryError {
  QueryError
}

pub fn query(json: JsonValue, path: JsonPath) -> Result(JsonValue, QueryError) {
  list.try_fold(path, [json], fn(acc, segment) {
    use l <- result.try(do_query(acc, segment))
    Ok(l)
  })
  |> result.map(fn(l) { JsonArray(parser.list_to_indexed_dict(l)) })
}

fn do_query(
  json: List(JsonValue),
  segment: Segment,
) -> Result(List(JsonValue), QueryError) {
  list.try_fold(json, [], fn(acc, j) {
    use results <- result.try(case segment {
      Child(selectors) -> process_selectors(selectors, [j])
      Descendant(selectors) ->
        process_selectors(selectors, get_descendants([j], j) |> echo)
    })
    Ok(list.append(acc, results))
  })
}

fn process_selectors(
  selectors: List(Selector),
  nodes: List(JsonValue),
) -> Result(List(JsonValue), QueryError) {
  list.try_fold(nodes, [], fn(arr, node) {
    use found <- result.try(do_checks(node, selectors))

    Ok(list.append(arr, found))
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
) -> Result(List(JsonValue), QueryError) {
  list.try_fold(selectors, [], fn(list, selector) {
    use found <- result.try(do_selector(json, selector))
    Ok(list.append(list, found))
  })
}

fn do_selector(
  json: JsonValue,
  selector: Selector,
) -> Result(List(JsonValue), QueryError) {
  case selector {
    jsonpath.Filter(expr:) -> todo
    jsonpath.Index(i:) -> do_index(json, i)
    jsonpath.Name(name:) -> do_name(json, name)
    jsonpath.Slice(start:, end:, step:) -> {
      do_slice(json, start, end, step)
    }
    jsonpath.Wildcard -> do_wildcard(json)
  }
}

fn do_slice(
  json: JsonValue,
  start: Option(Int),
  end: Option(Int),
  step: Option(Int),
) -> Result(List(JsonValue), QueryError) {
  case json {
    JsonArray(d) -> {
      use <- bool.guard(when: step == Some(0), return: Ok([]))
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
            order.Gt -> {
              case acc < end {
                True -> yielder.Next(acc, acc + step)
                False -> yielder.Done
              }
            }
            order.Lt -> {
              case acc > end {
                True -> yielder.Next(acc, acc + step)
                False -> yielder.Done
              }
            }
            order.Eq -> panic
          }
        })

      use l <- result.try(
        yielder.try_fold(yielder, [], fn(l, index) {
          case dict.get(d, index) {
            Error(_) -> Error(QueryError)
            Ok(v) -> Ok([v, ..l])
          }
        }),
      )
      Ok(list.reverse(l))
    }
    _ -> Ok([])
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

fn do_index(json: JsonValue, index: Int) -> Result(List(JsonValue), QueryError) {
  case json {
    JsonArray(d) -> {
      case index >= 0 {
        True -> {
          case dict.get(d, index) {
            Ok(j) -> Ok([j])
            _ -> Ok([])
          }
        }
        False -> {
          let index = dict.size(d) + index
          case index < 0 {
            True -> Ok([])
            False -> {
              case dict.get(d, index) {
                Ok(j) -> Ok([j])
                _ -> Ok([])
              }
            }
          }
        }
      }
    }
    _ -> Ok([])
  }
}

fn do_wildcard(json: JsonValue) -> Result(List(JsonValue), QueryError) {
  case json |> echo {
    JsonArray(d) -> Ok(dict.values(d)) |> echo
    JsonObject(d) -> Ok(dict.values(d)) |> echo
    _ -> Ok([])
  }
}

fn do_name(json: JsonValue, name: String) -> Result(List(JsonValue), QueryError) {
  case json {
    JsonObject(d) -> {
      case dict.get(d, name) {
        Ok(v) -> Ok([v])
        _ -> Ok([])
      }
    }
    _ -> Ok([])
  }
}
