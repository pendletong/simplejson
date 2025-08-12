import bigdecimal.{type BigDecimal}
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplejson/jsonvalue.{
  type JsonPathError, type JsonValue, ComparisonError, FunctionError,
  IndexOutOfRange, MissingRoot, NoMatch, ParseError,
}

pub type JsonPath =
  List(Segment)

pub type Selector {
  Name(name: String)
  Wildcard
  Index(i: Int)
  Slice(start: Option(Int), end: Option(Int), step: Option(Int))
  Filter(expr: LogicalExpression)
}

pub type Segment {
  Child(List(Selector))
  Descendant(List(Selector))
}

type Type {
  Value
  Logical
  Nodes
}

pub type TypeValue {
  ValueType(Literal)
  LogicalType(Bool)
  NodesType(List(JsonValue))
}

const min_int = -9_007_199_254_740_991

const max_int = 9_007_199_254_740_991

pub fn parse_path(str: String) -> Result(JsonPath, JsonPathError) {
  case str {
    "$" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))
      case rest {
        "" -> Ok(path)
        _ -> Error(ParseError("parse_path"))
      }
    }
    _ -> Error(MissingRoot)
  }
}

fn do_parse_segments(
  str: String,
  segments: List(Segment),
) -> Result(#(List(Segment), String), JsonPathError) {
  let rest = trim_whitespace(str)
  case do_parse_segment(rest) {
    Error(NoMatch) if segments == [] -> Ok(#([], str))
    Error(NoMatch) -> Ok(#(list.reverse(segments), rest))
    Ok(#(segment, rest)) -> {
      do_parse_segments(rest, [segment, ..segments])
    }
    Error(e) -> Error(e)
  }
}

fn do_parse_segment(str: String) -> Result(#(Segment, String), JsonPathError) {
  case str {
    ".." <> rest -> {
      do_parse_descendent_segment(rest)
    }
    "." <> _ | "[" <> _ -> {
      do_parse_child_segment(str)
    }
    _ -> Error(NoMatch)
  }
}

fn member_name_to_selector(
  f: fn(String) -> Result(#(String, String), JsonPathError),
) -> fn(String) -> Result(#(Selector, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(name, rest)) -> Ok(#(Name(name), rest))
      Error(a) -> Error(a)
    }
  }
}

fn selector_to_segment(
  res: Result(#(List(Selector), String), JsonPathError),
  seg: fn(List(Selector)) -> Segment,
) -> Result(#(Segment, String), JsonPathError) {
  case res {
    Ok(#(sel, rest)) -> Ok(#(seg(sel), rest))
    Error(e) -> Error(e)
  }
}

fn selector_to_selectors(
  res: fn(String) -> Result(#(Selector, String), JsonPathError),
) {
  fn(str) { result.map(res(str), fn(r) { #([r.0], r.1) }) }
}

fn do_parse_child_segment(
  str: String,
) -> Result(#(Segment, String), JsonPathError) {
  case str {
    "." <> rest -> {
      [
        selector_to_selectors(parse_wildcard_selector),
        selector_to_selectors(member_name_to_selector(parse_member_name)),
      ]
      |> try_options(rest)
      |> selector_to_segment(Child)
    }
    "[" <> _ -> {
      use #(sels, rest) <- result.try(parse_bracketed_selection(str))
      Ok(#(Child(sels), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn parse_wildcard_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  case str {
    "*" <> rest -> Ok(#(Wildcard, rest))
    _ -> Error(NoMatch)
  }
}

fn do_parse_descendent_segment(
  str: String,
) -> Result(#(Segment, String), JsonPathError) {
  [
    selector_to_selectors(parse_wildcard_selector),
    selector_to_selectors(member_name_to_selector(parse_member_name)),
    parse_bracketed_selection,
  ]
  |> try_options(str)
  |> selector_to_segment(Descendant)
}

fn parse_bracketed_selection(
  str: String,
) -> Result(#(List(Selector), String), JsonPathError) {
  do_parse_bracketed_selection(str, [])
}

fn do_parse_bracketed_selection(
  str: String,
  selectors: List(Selector),
) -> Result(#(List(Selector), String), JsonPathError) {
  case str {
    "[" <> _ if selectors != [] ->
      Error(ParseError("do_parse_bracketed_selection 1"))
    "," <> _ if selectors == [] ->
      Error(ParseError("do_parse_bracketed_selection 2"))
    "[" <> rest | "," <> rest -> {
      let rest = trim_whitespace(rest)
      use #(sel, rest) <- result.try(do_parse_selector(rest))
      do_parse_bracketed_selection(trim_whitespace(rest), [sel, ..selectors])
    }
    "]" <> rest -> Ok(#(list.reverse(selectors), rest))
    _ -> Error(NoMatch)
  }
}

fn try_options(options, str: String) {
  list.fold_until(options, Error(NoMatch), fn(_, parsefn) {
    case parsefn(str) {
      Error(NoMatch) -> Continue(Error(NoMatch))
      Error(e) -> Stop(Error(e))
      Ok(#(expr, str)) -> Stop(Ok(#(expr, str)))
    }
  })
}

fn do_parse_selector(str: String) -> Result(#(Selector, String), JsonPathError) {
  [
    parse_wildcard_selector,
    member_name_to_selector(parse_string_literal),
    parse_slice_selector,
    parse_index_selector,
    parse_filter_selector,
  ]
  |> try_options(str)
}

fn parse_index_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  case get_next_int(str, False) {
    Ok(#(val1, rest)) -> Ok(#(Index(val1), rest))
    Error(_) -> Error(NoMatch)
  }
}

fn parse_slice_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  use #(val1, rest) <- result.try(case get_next_int(str, False) {
    Error(_) -> {
      let str = trim_whitespace(str)
      case str {
        ":" <> rest -> Ok(#(None, rest))
        _ -> Error(NoMatch)
      }
    }
    Ok(#(i, rest)) -> {
      let rest = trim_whitespace(rest)
      case rest {
        ":" <> rest -> Ok(#(Some(i), rest))
        _ -> Error(NoMatch)
      }
    }
  })
  let rest = trim_whitespace(rest)
  use #(val2, rest) <- result.try(case get_next_int(rest, False) {
    Error(_) -> {
      let rest = trim_whitespace(rest)
      case rest {
        ":" <> rest -> Ok(#(None, rest))
        rest -> Ok(#(None, rest))
      }
    }
    Ok(#(i, rest)) -> {
      let rest = trim_whitespace(rest)
      case rest {
        ":" <> rest -> Ok(#(Some(i), rest))
        rest -> Ok(#(Some(i), rest))
      }
    }
  })
  let rest = trim_whitespace(rest)
  let rest = trim_whitespace(rest)
  use #(val3, rest) <- result.try(case get_next_int(rest, False) {
    Error(_) -> Ok(#(None, rest))
    Ok(#(i, rest)) -> Ok(#(Some(i), rest))
  })
  Ok(#(Slice(val1, val2, val3), rest))
}

fn parse_string_literal(str: String) -> Result(#(String, String), JsonPathError) {
  case str {
    "\"" as quote <> rest | "'" as quote <> rest -> {
      do_parse_string_literal(rest, quote, "")
    }
    _ -> Error(NoMatch)
  }
}

fn do_parse_string_literal(
  str: String,
  quote: String,
  literal: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) -> Error(ParseError("do_parse_string_literal1 "))
    Ok(#("\"", rest)) -> {
      case quote == "\"" {
        True -> Ok(#(literal, rest))
        False -> do_parse_string_literal(rest, quote, literal <> "\"")
      }
    }
    Ok(#("'", rest)) -> {
      case quote == "'" {
        True -> Ok(#(literal, rest))
        False -> do_parse_string_literal(rest, quote, literal <> "'")
      }
    }
    Ok(#("\\", rest)) -> {
      case rest {
        "\"" <> _rest if quote == "'" ->
          Error(ParseError("do_parse_string_literal 2"))
        "\"" <> rest -> do_parse_string_literal(rest, quote, literal <> "\"")
        "'" <> _rest if quote == "\"" ->
          Error(ParseError("do_parse_string_literal 3"))
        "'" <> rest -> do_parse_string_literal(rest, quote, literal <> "'")
        "b" <> rest ->
          do_parse_string_literal(rest, quote, literal <> "\u{0008}")
        "f" <> rest -> do_parse_string_literal(rest, quote, literal <> "\f")
        "n" <> rest -> do_parse_string_literal(rest, quote, literal <> "\n")
        "r" <> rest -> do_parse_string_literal(rest, quote, literal <> "\r")
        "t" <> rest -> do_parse_string_literal(rest, quote, literal <> "\t")
        "\\" <> rest -> do_parse_string_literal(rest, quote, literal <> "\\")
        "/" <> rest -> do_parse_string_literal(rest, quote, literal <> "/")
        "u" <> rest -> {
          use #(hexchar, rest) <- result.try(do_parse_hexchar(rest))
          do_parse_string_literal(rest, quote, literal <> hexchar)
        }
        _ -> Error(ParseError("do_parse_string_literal 4"))
      }
    }
    Ok(#(char, rest)) -> {
      let assert [codepoint] = string.to_utf_codepoints(char)
      let cpi = string.utf_codepoint_to_int(codepoint)
      case valid_literal_char(cpi) {
        True -> do_parse_string_literal(rest, quote, literal <> char)
        False -> Error(ParseError("do_parse_string_literal 5"))
      }
    }
  }
}

fn parse_member_name(str: String) -> Result(#(String, String), JsonPathError) {
  do_parse_member_name(str, "")
}

fn do_parse_member_name(
  str: String,
  name: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) if name == "" -> Error(NoMatch)
    Error(_) -> Ok(#(name, ""))
    Ok(#(ch, rest)) -> {
      case name == "" {
        True -> {
          case is_name_first(ch) {
            True -> do_parse_member_name(rest, name <> ch)
            False -> Error(NoMatch)
          }
        }
        False -> {
          case is_name_char(ch) {
            True -> do_parse_member_name(rest, name <> ch)
            False -> Ok(#(name, str))
          }
        }
      }
    }
  }
}

fn is_name_first(char: String) -> Bool {
  use <- bool.guard(when: char == "_", return: True)

  let assert [codepoint] = string.to_utf_codepoints(char)
  let cpi = string.utf_codepoint_to_int(codepoint)
  case cpi {
    _ if cpi >= 0x41 && cpi <= 0x5A -> True
    _ if cpi >= 0x61 && cpi <= 0x7A -> True
    _ if cpi >= 0x80 && cpi <= 0xD7FF -> True
    _ if cpi >= 0xE0000 && cpi <= 0x10FFFF -> True
    _ -> False
  }
}

fn is_name_char(char: String) -> Bool {
  case is_name_first(char) {
    True -> True
    False -> is_digit(char)
  }
}

fn valid_literal_char(cpi: Int) -> Bool {
  case cpi {
    0x20 | 0x21 | 0x23 | 0x24 | 0x25 | 0x26 -> True
    _ if cpi >= 0x28 && cpi <= 0x5B -> True
    _ if cpi >= 0x5D && cpi <= 0xD7FF -> True
    _ if cpi >= 0xE000 && cpi <= 0x10FFFF -> True
    _ -> False
  }
}

fn do_parse_hexchar(str: String) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) -> Error(ParseError("do_parse_hexchar 1"))
    Ok(#(char, rest)) -> {
      case string.lowercase(char) {
        "0"
        | "1"
        | "2"
        | "3"
        | "4"
        | "5"
        | "6"
        | "7"
        | "8"
        | "9"
        | "a"
        | "b"
        | "c"
        | "e"
        | "f" -> {
          use #(hex, rest) <- result.try(parse_hex_digit(rest, 3))
          use ns <- result.try(decode_non_surrogate(char <> hex))
          Ok(#(ns, rest))
        }
        "d" -> {
          case string.pop_grapheme(rest) {
            Error(_) -> Error(ParseError("do_parse_hexchar 2"))
            Ok(#(char2, rest)) -> {
              case string.lowercase(char2) {
                "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" -> {
                  use #(hex, rest) <- result.try(parse_hex_digit(rest, 2))
                  use ns <- result.try(decode_non_surrogate(
                    char <> char2 <> hex,
                  ))
                  Ok(#(ns, rest))
                }
                "8" | "9" | "a" | "b" -> {
                  use #(hex, rest) <- result.try(parse_hex_digit(rest, 2))
                  use #(low, rest) <- result.try(parse_low_surrogate(rest))
                  use codepoint <- result.try(convert_surrogate(
                    char <> char2 <> hex,
                    low,
                  ))
                  use codepoint <- result.try(
                    string.utf_codepoint(codepoint)
                    |> result.replace_error(ParseError("do_parse_hexchar 3")),
                  )
                  Ok(#(string.from_utf_codepoints([codepoint]), rest))
                }
                _ -> Error(ParseError("do_parse_hexchar 4"))
              }
            }
          }
        }
        _ -> Error(ParseError("do_parse_hexchar 5"))
      }
    }
  }
}

fn convert_surrogate(high: String, low: String) {
  use high <- result.try(
    int.base_parse(high, 16)
    |> result.replace_error(ParseError("convert_surrogate 1")),
  )
  use low <- result.try(
    int.base_parse(low, 16)
    |> result.replace_error(ParseError("convert_surrogate 2")),
  )

  Ok({ { high - 0xD800 } * 0x400 } + { { low - 0xDC00 } + 0x10000 })
}

fn parse_low_surrogate(str: String) -> Result(#(String, String), JsonPathError) {
  case str {
    "\\u" <> rest -> {
      use #(hex, rest) <- result.try(parse_hex_digit(rest, 4))
      case string.lowercase(hex) {
        "dc" <> _ | "dd" <> _ | "de" <> _ | "df" <> _ -> {
          Ok(#(hex, rest))
        }
        _ -> Error(ParseError("parse_low_surrogate 1"))
      }
    }
    _ -> Error(ParseError("parse_low_surrogate 2"))
  }
}

fn parse_hex_digit(
  str: String,
  num: Int,
) -> Result(#(String, String), JsonPathError) {
  list.repeat(0, num)
  |> list.try_fold(#("", str), fn(acc, _) {
    let #(hex, str2) = acc
    case string.pop_grapheme(str2) {
      Error(_) -> Error(ParseError("parse_hex_digit 1"))
      Ok(#(char, rest)) -> {
        case string.lowercase(char) {
          "0"
          | "1"
          | "2"
          | "3"
          | "4"
          | "5"
          | "6"
          | "7"
          | "8"
          | "9"
          | "a"
          | "b"
          | "c"
          | "d"
          | "e"
          | "f" -> Ok(#(hex <> char, rest))
          _ -> Error(ParseError("parse_hex_digit 2"))
        }
      }
    }
  })
}

fn decode_non_surrogate(hex: String) -> Result(String, JsonPathError) {
  use i <- result.try(
    int.base_parse(hex, 16)
    |> result.replace_error(ParseError("decode_non_surrogate 1")),
  )
  use codepoint <- result.try(
    string.utf_codepoint(i)
    |> result.replace_error(ParseError("decode_non_surrogate 2")),
  )
  Ok(string.from_utf_codepoints([codepoint]))
}

fn parse_filter_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  case str {
    "?" <> rest -> {
      let rest = trim_whitespace(rest)
      use #(le, rest) <- result.try(do_parse_logical_expr(rest))
      Ok(#(Filter(le), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn do_parse_logical_expr(
  str: String,
) -> Result(#(LogicalExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case do_parse_logical_or_expr(str, LogicalOrExpression([])) {
    Ok(#(LogicalOrExpression(lo), rest)) ->
      Ok(#(LogicalExpression(LogicalOrExpression(list.reverse(lo))), rest))
    _ -> Error(NoMatch)
  }
}

fn do_parse_logical_or_expr(
  str: String,
  cur: LogicalOrExpression,
) -> Result(#(LogicalOrExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case str, cur {
    "||" <> rest, LogicalOrExpression(cur_list)
    | rest, LogicalOrExpression(cur_list)
    -> {
      case do_parse_logical_and_expr(rest, LogicalAndExpression([])) {
        Ok(#(LogicalAndExpression(lae), rest)) ->
          do_parse_logical_or_expr(
            rest,
            LogicalOrExpression([
              LogicalAndExpression(list.reverse(lae)),
              ..cur_list
            ]),
          )
        Error(_) if cur == LogicalOrExpression([]) -> Error(NoMatch)
        Error(_) -> Ok(#(cur, str))
      }
    }
  }
}

fn do_parse_logical_and_expr(
  str: String,
  cur: LogicalAndExpression,
) -> Result(#(LogicalAndExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case str, cur {
    "&&" <> rest, LogicalAndExpression(cur_list)
    | rest, LogicalAndExpression(cur_list)
    -> {
      case do_parse_basic_expr(rest) {
        Ok(#(expr, rest)) ->
          do_parse_logical_and_expr(
            rest,
            LogicalAndExpression([expr, ..cur_list]),
          )
        Error(_) if cur == LogicalAndExpression([]) -> Error(NoMatch)
        Error(_) -> Ok(#(cur, str))
      }
    }
  }
}

fn do_parse_basic_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  let str = trim_whitespace(str)
  [
    do_parse_paren_expr,
    do_parse_comparison_expr,
    do_parse_test_expr,
  ]
  |> try_options(str)
}

fn do_parse_test_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  let #(not, str) = case str {
    "!" <> rest -> #(True, rest)
    _ -> #(False, str)
  }
  let str = trim_whitespace(str)
  [
    filter_to_testexpression(do_parse_filter_query),
    function_to_testexpression(do_parse_function_expr),
  ]
  // |>try_options(str)
  |> list.fold_until(Error(NoMatch), fn(_, parsefn) {
    case parsefn(str) {
      Error(NoMatch) -> Continue(Error(NoMatch))
      Error(e) -> Stop(Error(e))
      Ok(#(expr, str)) -> Stop(Ok(#(Test(expr, not), str)))
    }
  })
}

fn filter_to_testexpression(
  f: fn(String) -> Result(#(Filter, String), JsonPathError),
) -> fn(String) -> Result(#(TestExpression, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(FilterQuery(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn do_parse_filter_query(
  str: String,
) -> Result(#(Filter, String), JsonPathError) {
  case str {
    "$" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))

      Ok(#(Root(path), rest))
    }
    "@" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))
      Ok(#(Relative(path), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn function_to_testexpression(
  f: fn(String) -> Result(#(Function, String), JsonPathError),
) -> fn(String) -> Result(#(TestExpression, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(f, rest)) -> {
        case get_return_type(f.deffn) {
          Logical | Nodes -> Ok(#(FunctionExpr(f), rest))
          Value -> Error(FunctionError)
        }
      }
      Error(a) -> Error(a)
    }
  }
}

fn do_parse_function_expr(
  str: String,
) -> Result(#(Function, String), JsonPathError) {
  use #(name, rest) <- result.try(do_parse_function_name(str, ""))

  case rest {
    "(" <> rest -> {
      use #(args, rest) <- result.try(do_parse_function_args(rest, []))
      let rest = trim_whitespace(rest)
      case rest {
        ")" <> rest -> {
          let deffn = name_to_function(name)
          case validate_function(Function(deffn:, args:)) {
            True -> Ok(#(Function(deffn:, args:), rest))
            False -> Error(FunctionError)
          }
        }
        _ -> Error(NoMatch)
      }
    }
    _ -> Error(NoMatch)
  }
}

fn name_to_function(str: String) -> DefinedFunction {
  case str {
    "count" -> Count
    "length" -> Length
    "match" -> Match
    "search" -> Search
    "value" -> ValueOf
    _ -> Unknown(str)
  }
}

fn get_arg_type(arg: FunctionArgument) -> Type {
  case arg {
    FunctionArg(Function(deffn, _)) -> get_return_type(deffn)
    LiteralArg(_) -> Value
    LogicalArg(_) -> Logical
    QueryArg(_) -> Nodes
    QuerySingularArg(_) -> Value
  }
}

fn validate_function(f: Function) -> Bool {
  case f {
    Function(Count, [param]) -> {
      case param {
        QuerySingularArg(_) -> True
        _ -> {
          case get_arg_type(param) {
            Nodes -> True
            _ -> False
          }
        }
      }
    }
    Function(Length, [param]) -> {
      case get_arg_type(param) {
        Value -> True
        _ -> False
      }
    }
    Function(Match, [param1, param2]) -> {
      case get_arg_type(param1), get_arg_type(param2) {
        Value, Value -> True
        _, _ -> False
      }
    }
    Function(Search, [param1, param2]) -> {
      case get_arg_type(param1), get_arg_type(param2) {
        Value, Value -> True
        _, _ -> False
      }
    }
    Function(Unknown(_), _) -> {
      True
    }
    Function(ValueOf, [param]) -> {
      case get_arg_type(param) {
        Nodes -> True
        Value -> True
        _ -> False
      }
    }
    _ -> False
  }
}

fn do_parse_function_args(
  str: String,
  args: List(FunctionArgument),
) -> Result(#(List(FunctionArgument), String), JsonPathError) {
  let rest = trim_whitespace(str)
  case rest {
    "," <> rest -> do_parse_function_args(rest, args)
    rest -> {
      case do_parse_function_arg(rest) {
        Ok(#(arg, rest)) -> do_parse_function_args(rest, [arg, ..args])
        Error(_) if args == [] -> Error(NoMatch)
        Error(_) -> Ok(#(list.reverse(args), rest))
      }
    }
  }
}

fn do_parse_function_arg(
  str: String,
) -> Result(#(FunctionArgument, String), JsonPathError) {
  [
    literal_to_arg(do_parse_literal),
    // singularquery_to_arg(parse_singular_query),
    filter_to_arg(do_parse_filter_query),
    logical_to_arg(do_parse_logical_expr),
    function_to_arg(do_parse_function_expr),
  ]
  |> try_options(str)
}

// LiteralArg(Literal)
// QueryArg(Filter)
// QuerySingularArg(SingularQuery)
// LogicalArg(LogicalExpression)
// FunctionArg(Function)
fn function_to_arg(
  f: fn(String) -> Result(#(Function, String), JsonPathError),
) -> fn(String) -> Result(#(FunctionArgument, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(filter, rest)) -> Ok(#(FunctionArg(filter), rest))
      Error(a) -> Error(a)
    }
  }
}

fn logical_to_arg(
  f: fn(String) -> Result(#(LogicalExpression, String), JsonPathError),
) -> fn(String) -> Result(#(FunctionArgument, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(filter, rest)) -> Ok(#(LogicalArg(filter), rest))
      Error(a) -> Error(a)
    }
  }
}

// fn singularquery_to_arg(
//   f: fn(String) -> Result(#(SingularQuery, String), JsonPathError),
// ) -> fn(String) -> Result(#(FunctionArgument, String), JsonPathError) {
//   fn(str) {
//     case f(str) {
//       Ok(#(filter, rest)) -> Ok(#(QuerySingularArg(filter), rest))
//       Error(a) -> Error(a)
//     }
//   }
// }

fn filter_to_arg(
  f: fn(String) -> Result(#(Filter, String), JsonPathError),
) -> fn(String) -> Result(#(FunctionArgument, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(filter, rest)) -> {
        case is_singular(filter) {
          True -> Ok(#(QuerySingularArg(filter), rest))
          False -> Ok(#(QueryArg(filter), rest))
        }
      }
      Error(a) -> Error(a)
    }
  }
}

fn is_singular(filter: Filter) -> Bool {
  list.find(filter.path, fn(seg) {
    case seg {
      Child(sels) | Descendant(sels) -> {
        case sels {
          [sel] -> {
            case sel {
              Filter(_) -> True
              Index(_) -> False
              Name(_) -> False
              Slice(_, _, _) -> True
              Wildcard -> True
            }
          }
          _ -> True
        }
      }
    }
  })
  |> result.replace(False)
  |> result.replace_error(True)
  |> result.unwrap_both
}

fn literal_to_arg(
  f: fn(String) -> Result(#(Literal, String), JsonPathError),
) -> fn(String) -> Result(#(FunctionArgument, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(LiteralArg(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn do_parse_function_name(
  str: String,
  cur: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) -> Error(ParseError("do_parse_function_name"))
    Ok(#(char, rest)) -> {
      case is_lc_alpha(char) {
        True if cur == "" -> do_parse_function_name(rest, char)
        True -> do_parse_function_name(rest, cur <> char)
        False if cur == "" -> Error(NoMatch)
        False -> {
          case char == "_" || is_digit(char) {
            True -> do_parse_function_name(rest, cur <> char)
            False -> Ok(#(cur, str))
          }
        }
      }
    }
  }
}

fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

fn is_lc_alpha(char: String) -> Bool {
  case string.to_utf_codepoints(char) {
    [u] | [u, ..] -> {
      case string.utf_codepoint_to_int(u) {
        ui if ui >= 0x61 && ui <= 0x7A -> True
        _ -> False
      }
    }
    [] -> False
  }
}

fn do_parse_comparison_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  use #(cmp1, rest) <- result.try(do_parse_comparable(str))
  let rest = trim_whitespace(rest)
  use #(cmpop, rest) <- result.try(do_parse_comparisonop(rest))
  let rest = trim_whitespace(rest)
  use #(cmp2, rest) <- result.try(do_parse_comparable(rest))
  case validate_comparison(cmp1, cmp2, cmpop) {
    True -> Ok(#(Comparison(cmp1, cmp2, cmpop), rest))
    False -> Error(ComparisonError)
  }
}

fn validate_comparison(
  cmp1: Comparable,
  cmp2: Comparable,
  _cmpop: CompareOp,
) -> Bool {
  case get_comparable_return_type(cmp1), get_comparable_return_type(cmp2) {
    Logical, _ | _, Logical -> False
    _, _ -> True
  }
}

fn get_comparable_return_type(cmp: Comparable) -> Type {
  case cmp {
    FunctionExprCmp(Function(deffn, _)) -> get_return_type(deffn)
    Literal(_) -> Value
    QueryCmp(_) -> Value
  }
}

fn do_parse_comparisonop(
  str: String,
) -> Result(#(CompareOp, String), JsonPathError) {
  case str {
    "==" <> rest -> Ok(#(Eq, rest))
    ">=" <> rest -> Ok(#(Gte, rest))
    "<=" <> rest -> Ok(#(Lte, rest))
    "!=" <> rest -> Ok(#(NotEq, rest))
    ">" <> rest -> Ok(#(Gt, rest))
    "<" <> rest -> Ok(#(Lt, rest))
    _ -> Error(NoMatch)
  }
}

fn literal_to_comparable(
  f: fn(String) -> Result(#(Literal, String), JsonPathError),
) -> fn(String) -> Result(#(Comparable, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(Literal(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn do_parse_comparable(
  str: String,
) -> Result(#(Comparable, String), JsonPathError) {
  [
    literal_to_comparable(do_parse_literal),
    singular_to_comparable(parse_singular_query),
    function_to_comparable(do_parse_function_expr),
  ]
  |> try_options(str)
}

fn function_to_comparable(
  f: fn(String) -> Result(#(Function, String), JsonPathError),
) -> fn(String) -> Result(#(Comparable, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(FunctionExprCmp(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn singular_to_comparable(
  f: fn(String) -> Result(#(SingularQuery, String), JsonPathError),
) -> fn(String) -> Result(#(Comparable, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(QueryCmp(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn parse_singular_query(
  str: String,
) -> Result(#(SingularQuery, String), JsonPathError) {
  case str {
    "@" <> rest -> {
      use #(segs, rest) <- result.try(do_parse_singular_query(rest, []))
      Ok(#(RelQuery(segs), rest))
    }
    "$" <> rest -> {
      use #(segs, rest) <- result.try(do_parse_singular_query(rest, []))
      Ok(#(AbsQuery(segs), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn do_parse_singular_query(
  str: String,
  cur: List(SingularSegment),
) -> Result(#(List(SingularSegment), String), JsonPathError) {
  case do_parse_singular_query_segments(str) {
    Ok(#(seg, rest)) -> {
      do_parse_singular_query(rest, [seg, ..cur])
    }
    Error(_) if cur == [] -> Ok(#([], str))
    Error(_) -> Ok(#(list.reverse(cur), str))
  }
}

fn do_parse_singular_query_segments(
  str: String,
) -> Result(#(SingularSegment, String), JsonPathError) {
  let str = trim_whitespace(str)
  [
    parse_name_selector_segment,
    parse_member_name_segment,
    parse_index_segment,
  ]
  |> try_options(str)
}

fn parse_index_segment(
  str: String,
) -> Result(#(SingularSegment, String), JsonPathError) {
  case str {
    "[" <> rest -> {
      use #(i, rest) <- result.try(get_next_int(rest, False))
      case rest {
        "]" <> rest -> Ok(#(SingleIndex(i), rest))
        _ -> Error(NoMatch)
      }
    }
    _ -> Error(NoMatch)
  }
}

fn parse_member_name_segment(
  str: String,
) -> Result(#(SingularSegment, String), JsonPathError) {
  case str {
    "." <> rest -> {
      use #(name, rest) <- result.try(parse_member_name(rest))
      Ok(#(SingleName(name), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn parse_name_selector_segment(
  str: String,
) -> Result(#(SingularSegment, String), JsonPathError) {
  case str {
    "[" <> rest -> {
      use #(name, rest) <- result.try(parse_string_literal(rest))
      case rest {
        "]" <> rest -> Ok(#(SingleName(name), rest))
        _ -> Error(NoMatch)
      }
    }
    _ -> Error(NoMatch)
  }
}

fn string_to_literal(
  f: fn(String) -> Result(#(String, String), JsonPathError),
) -> fn(String) -> Result(#(Literal, String), JsonPathError) {
  fn(str) {
    case f(str) {
      Ok(#(lit, rest)) -> Ok(#(String(lit), rest))
      Error(a) -> Error(a)
    }
  }
}

fn do_parse_literal(str: String) -> Result(#(Literal, String), JsonPathError) {
  case str {
    "true" <> rest -> Ok(#(Boolean(True), rest))
    "false" <> rest -> Ok(#(Boolean(False), rest))
    "null" <> rest -> Ok(#(Null, rest))
    _ -> {
      [
        parse_literal_number,
        string_to_literal(parse_string_literal),
      ]
      |> try_options(str)
    }
  }
}

pub fn parse_literal_number(
  str: String,
) -> Result(#(Literal, String), JsonPathError) {
  use #(neg, int, rest) <- result.try(case str {
    "-0" <> rest -> Ok(#(True, 0, rest))
    rest -> {
      use #(i, rest) <- result.try(get_next_int(rest, False))
      Ok(#(i < 0, int.absolute_value(i), rest))
    }
  })

  use #(frac, rest) <- result.try(case rest {
    ".-" <> _ -> Error(NoMatch)
    "." <> rest -> {
      case get_next_int_as_string(rest, True, "") {
        Error(_) -> Error(NoMatch)
        Ok(#(i, rest)) -> Ok(#(Some(i), rest))
      }
    }
    _ -> Ok(#(None, rest))
  })

  use #(exp, rest) <- result.try(case rest {
    "E+-" <> _ | "e+-" <> _ -> Error(ParseError("parse_literal_number"))
    "E+" <> rest | "e+" <> rest | "E" <> rest | "e" <> rest -> {
      case get_next_int(rest, True) {
        Error(_) -> Error(NoMatch)
        Ok(#(i, rest)) -> Ok(#(Some(i), rest))
      }
    }
    _ -> Ok(#(None, rest))
  })

  let num =
    {
      case neg {
        True -> "-"
        False -> ""
      }
    }
    <> int.to_string(int)
    <> {
      case frac {
        Some(f) -> "." <> f
        None -> ""
      }
    }
    <> {
      case exp {
        Some(e) -> "e" <> int.to_string(e)
        None -> ""
      }
    }

  use num <- result.try(
    bigdecimal.from_string(num)
    |> result.replace_error(ParseError("parse_literal_number")),
  )

  Ok(#(Number(num), rest))
}

fn do_parse_paren_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  let #(not, str) = case str {
    "!" <> rest -> #(True, rest)
    _ -> #(False, str)
  }
  let str = trim_whitespace(str)

  case str {
    "(" <> rest -> {
      use #(le, rest) <- result.try(do_parse_logical_expr(rest))
      let rest = trim_whitespace(rest)
      case rest {
        ")" <> rest -> Ok(#(Paren(le, not), rest))
        _ -> Error(NoMatch)
      }
    }
    _ -> Error(NoMatch)
  }
}

fn get_next_int_as_string(
  str: String,
  allow_leading: Bool,
  cur: String,
) -> Result(#(String, String), JsonPathError) {
  case str {
    "-" <> rest if cur == "" -> get_next_int_as_string(rest, allow_leading, "-")
    "0" <> rest if cur == "" -> get_next_int_as_string(rest, allow_leading, "0")
    "0" <> _ if !allow_leading && cur == "-" ->
      Error(ParseError("get_next_int 1"))
    "0" <> _
      | "1" <> _
      | "2" <> _
      | "3" <> _
      | "4" <> _
      | "5" <> _
      | "6" <> _
      | "7" <> _
      | "8" <> _
      | "9" <> _
      if !allow_leading && cur == "0"
    -> Error(ParseError("get_next_int 2"))
    "0" as n <> rest
    | "1" as n <> rest
    | "2" as n <> rest
    | "3" as n <> rest
    | "4" as n <> rest
    | "5" as n <> rest
    | "6" as n <> rest
    | "7" as n <> rest
    | "8" as n <> rest
    | "9" as n <> rest -> get_next_int_as_string(rest, allow_leading, cur <> n)
    _ if cur == "" -> Error(NoMatch)
    _ -> {
      Ok(#(cur, str))
    }
  }
}

fn get_next_int(
  str: String,
  allow_leading: Bool,
) -> Result(#(Int, String), JsonPathError) {
  use #(next_int, str) <- result.try(get_next_int_as_string(
    str,
    allow_leading,
    "",
  ))
  case validate_int(next_int) {
    Error(e) -> Error(e)
    Ok(i) -> Ok(#(i, str))
  }
}

fn validate_int(str: String) -> Result(Int, JsonPathError) {
  case int.parse(str) {
    Ok(i) -> {
      case i < min_int {
        False -> {
          case i > max_int {
            False -> Ok(i)
            True -> Error(IndexOutOfRange(i))
          }
        }
        True -> Error(IndexOutOfRange(i))
      }
    }
    Error(_) -> Error(ParseError("validate_int"))
  }
}

fn trim_whitespace(str: String) -> String {
  case str {
    " " <> rest | "\t" <> rest | "\n" <> rest | "\r" <> rest ->
      trim_whitespace(rest)
    _ -> str
  }
}

pub type LogicalExpression {
  LogicalExpression(or: LogicalOrExpression)
}

pub type LogicalAndExpression {
  LogicalAndExpression(and: List(Expression))
}

pub type LogicalOrExpression {
  LogicalOrExpression(ands: List(LogicalAndExpression))
}

pub type Literal {
  Number(n: BigDecimal)
  String(String)
  Boolean(Bool)
  Null
  Nothing
  Object(dict.Dict(String, JsonValue))
  Array(dict.Dict(Int, JsonValue))
}

pub type SingularSegment {
  SingleName(String)
  SingleIndex(Int)
}

pub type Comparable {
  Literal(Literal)
  QueryCmp(SingularQuery)
  FunctionExprCmp(Function)
}

pub type SingularQuery {
  RelQuery(List(SingularSegment))
  AbsQuery(List(SingularSegment))
}

pub type CompareOp {
  Eq
  NotEq
  Gt
  Gte
  Lt
  Lte
}

pub type TestExpression {
  FilterQuery(Filter)
  FunctionExpr(Function)
}

pub type Filter {
  Relative(path: JsonPath)
  Root(path: JsonPath)
}

pub type Function {
  Function(deffn: DefinedFunction, args: List(FunctionArgument))
}

pub type FunctionArgument {
  LiteralArg(Literal)
  QueryArg(Filter)
  QuerySingularArg(Filter)
  LogicalArg(LogicalExpression)
  FunctionArg(Function)
}

pub type DefinedFunction {
  Count
  Length
  Match
  Search
  ValueOf
  Unknown(name: String)
}

fn get_return_type(f: DefinedFunction) -> Type {
  case f {
    Count -> Value
    Length -> Value
    Match -> Logical
    Search -> Logical
    Unknown(_) -> Value
    ValueOf -> Value
  }
}

pub type Expression {
  Paren(expr: LogicalExpression, not: Bool)
  Comparison(cmp1: Comparable, cmp2: Comparable, cmpop: CompareOp)
  Test(expr: TestExpression, not: Bool)
}
