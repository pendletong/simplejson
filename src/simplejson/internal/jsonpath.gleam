import gleam/bool
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplejson/jsonvalue

pub type JsonPath =
  List(Segment)

pub opaque type Selector {
  Name(name: String)
  Wildcard
  Index(i: Int)
  Slice(start: Option(Int), end: Option(Int), step: Option(Int))
  Filter(expr: LogicalExpression)
}

pub opaque type Segment {
  Child(List(Selector))
  Descendant(List(Selector))
}

pub type JsonPathError {
  ParseError(context: String)
  MissingRoot
  IndexOutOfRange(i: Int)
  NoMatch
}

const min_int = -9_007_199_254_740_991

const max_int = 9_007_199_254_740_991

pub fn parse_path(str: String) -> Result(JsonPath, JsonPathError) {
  case str {
    "$" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))
      case rest {
        "" -> Ok(path)
        _ -> Error(ParseError(rest))
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
      |> try_options(rest, _)
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
  |> try_options(str, _)
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
    "[" <> _ if selectors != [] -> Error(ParseError(str))
    "," <> _ if selectors == [] -> Error(ParseError(str))
    "[" <> rest | "," <> rest -> {
      let rest = trim_whitespace(rest)
      use #(sel, rest) <- result.try(do_parse_selector(rest))

      do_parse_bracketed_selection(trim_whitespace(rest), [sel, ..selectors])
    }
    "]" <> rest -> Ok(#(list.reverse(selectors), rest))
    _ -> Error(NoMatch)
  }
}

fn try_options(str: String, options) {
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
    member_name_to_selector(parse_name_selector),
    parse_slice_selector,
    parse_index_selector,
    // parse_filter_selector,
  ]
  |> try_options(str, _)
}

fn parse_index_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  case get_next_int(str, "") {
    Ok(#(val1, rest)) -> Ok(#(Index(val1), rest))
    Error(_) -> Error(NoMatch)
  }
}

fn parse_slice_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  { "Slice1 " <> str } |> echo
  use #(val1, rest) <- result.try(case get_next_int(str, "") {
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
  { "Slice2 " <> rest } |> echo
  use #(val2, rest) <- result.try(case get_next_int(rest, "") {
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
  { "Slice3 " <> rest } |> echo
  let rest = trim_whitespace(rest)
  use #(val3, rest) <- result.try(case get_next_int(rest, "") |> echo {
    Error(_) -> Ok(#(None, rest))
    Ok(#(i, rest)) -> Ok(#(Some(i), rest))
  })
  Ok(#(Slice(val1, val2, val3), rest))
}

fn parse_name_selector(str: String) -> Result(#(String, String), JsonPathError) {
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
    Error(_) -> Error(ParseError(str))
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
        "\"" <> _rest if quote == "'" -> Error(ParseError(str))
        "\"" <> rest -> do_parse_string_literal(rest, quote, literal <> "\"")
        "'" <> _rest if quote == "\"" -> Error(ParseError(str))
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
        _ -> Error(ParseError(str))
      }
    }
    Ok(#(char, rest)) -> {
      let assert [codepoint] = string.to_utf_codepoints(char)
      let cpi = string.utf_codepoint_to_int(codepoint)
      case valid_literal_char(cpi) {
        True -> do_parse_string_literal(rest, quote, literal <> char)
        False -> Error(ParseError(str))
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
    Error(_) -> Error(ParseError(str))
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
            Error(_) -> Error(ParseError(str))
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
                    |> result.replace_error(ParseError(str)),
                  )
                  Ok(#(string.from_utf_codepoints([codepoint]), rest))
                }
                _ -> Error(ParseError(str))
              }
            }
          }
        }
        _ -> Error(ParseError(str))
      }
    }
  }
}

fn convert_surrogate(high: String, low: String) {
  use high <- result.try(
    int.base_parse(high, 16) |> result.replace_error(ParseError("")),
  )
  use low <- result.try(
    int.base_parse(low, 16) |> result.replace_error(ParseError("")),
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
        _ -> Error(ParseError(str))
      }
    }
    _ -> Error(ParseError(str))
  }
}

fn parse_hex_digit(
  str: String,
  num: Int,
) -> Result(#(String, String), JsonPathError) {
  list.repeat(0, num)
  |> list.try_fold(#("", str), fn(acc, i) {
    let #(hex, str2) = acc
    case string.pop_grapheme(str2) {
      Error(_) -> Error(ParseError(str))
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
          _ -> Error(ParseError(str))
        }
      }
    }
  })
}

fn decode_non_surrogate(hex: String) -> Result(String, JsonPathError) {
  use i <- result.try(
    int.base_parse(hex, 16) |> result.replace_error(ParseError(hex)),
  )
  use codepoint <- result.try(
    string.utf_codepoint(i) |> result.replace_error(ParseError(hex)),
  )
  Ok(string.from_utf_codepoints([codepoint]))
}

fn do_parse_filter_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  let str = trim_whitespace(str)
  use #(le, rest) <- result.try(do_parse_logical_expr(str))
  Ok(#(Filter(le), rest))
}

fn do_parse_logical_expr(
  str: String,
) -> Result(#(LogicalExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case do_parse_logical_or_expr(str, LogicalOrExpression([])) {
    Ok(#(LogicalOrExpression(lo), rest)) ->
      Ok(#(LogicalExpression(LogicalOrExpression(lo)), rest))
    _ -> Error(ParseError(str))
  }
}

fn do_parse_logical_or_expr(
  str: String,
  cur: LogicalOrExpression,
) -> Result(#(LogicalOrExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case str, cur {
    "||" <> _, LogicalOrExpression([]) -> Error(ParseError(str))
    "]" <> rest, _ | ")" <> rest, _ -> Ok(#(cur, rest))
    "", _ -> Error(ParseError(""))
    "||" <> rest, LogicalOrExpression(cur_list)
    | rest, LogicalOrExpression(cur_list)
    -> {
      use #(lae, rest) <- result.try(do_parse_logical_and_expr(
        rest,
        LogicalAndExpression([]),
      ))
      do_parse_logical_or_expr(rest, LogicalOrExpression([lae, ..cur_list]))
    }
  }
}

fn do_parse_logical_and_expr(
  str: String,
  cur: LogicalAndExpression,
) -> Result(#(LogicalAndExpression, String), JsonPathError) {
  let str = trim_whitespace(str)
  case str, cur {
    "&&" <> _, LogicalAndExpression([]) -> Error(ParseError(str))
    "]" <> _, _ | ")" <> _, _ -> Ok(#(cur, str))
    "", _ -> Error(ParseError(""))
    "&&" <> rest, LogicalAndExpression(cur_list)
    | rest, LogicalAndExpression(cur_list)
    -> {
      use #(be, rest) <- result.try(do_parse_basic_expr(rest))
      do_parse_logical_and_expr(rest, LogicalAndExpression([be, ..cur_list]))
    }
  }
}

fn do_parse_basic_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  let str = trim_whitespace(str)
  [do_parse_paren_expr, do_parse_comparison_expr, do_parse_test_expr]
  |> list.fold_until(Error(NoMatch), fn(_, parsefn) {
    case parsefn(str) {
      Error(NoMatch) -> Continue(Error(NoMatch))
      Error(e) -> Stop(Error(e))
      Ok(#(expr, str)) -> Stop(Ok(#(expr, str)))
    }
  })
}

fn do_parse_test_expr(
  str: String,
) -> Result(#(Expression, String), JsonPathError) {
  let #(not, str) = case str {
    "!" <> rest -> #(True, rest)
    _ -> #(False, str)
  }
  let str = trim_whitespace(str)
  [do_parse_filter_query, do_parse_function_expr]
  |> list.fold_until(Error(NoMatch), fn(_, parsefn) {
    case parsefn(str) {
      Error(NoMatch) -> Continue(Error(NoMatch))
      Error(e) -> Stop(Error(e))
      Ok(#(expr, str)) -> Stop(Ok(#(Test(expr, not), str)))
    }
  })
}

fn do_parse_filter_query(
  str: String,
) -> Result(#(TestExpression, String), JsonPathError) {
  case str {
    "$" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))

      Ok(#(FilterQuery(Root(path)), rest))
    }
    "@" <> rest -> {
      use #(path, rest) <- result.try(do_parse_segments(rest, []))

      Ok(#(FilterQuery(Relative(path)), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn do_parse_function_expr(
  str: String,
) -> Result(#(TestExpression, String), JsonPathError) {
  use #(name, rest) <- result.try(do_parse_function_name(str, ""))

  case rest {
    "(" <> rest -> {
      use #(args, rest) <- result.try(do_parse_function_args(rest, []))
      todo
    }
    _ -> Error(NoMatch)
  }
}

fn do_parse_function_args(
  str: String,
  args: List(FunctionArgument),
) -> Result(#(List(FunctionArgument), String), JsonPathError) {
  let rest = trim_whitespace(str)
  todo
}

fn do_parse_function_name(
  str: String,
  cur: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) -> Error(ParseError(str))
    Ok(#(char, rest)) -> {
      case is_lc_alpha(char) {
        True if cur == "" -> do_parse_function_name(rest, char)
        True -> {
          case char == "_" || is_digit(char) {
            True -> do_parse_function_name(rest, cur <> char)
            False -> Error(NoMatch)
          }
        }
        False if cur == "" -> Error(NoMatch)
        False -> Ok(#(cur, str))
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
  todo
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

      Ok(#(Paren(le, not), rest))
    }
    _ -> Error(NoMatch)
  }
}

fn get_next_int(
  str: String,
  cur: String,
) -> Result(#(Int, String), JsonPathError) {
  case str {
    "-" <> rest if cur == "" -> get_next_int(rest, "-")
    "0" <> rest if cur == "" -> get_next_int(rest, "0")
    "0" <> _ if cur == "-" -> Error(ParseError(str))
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
      if cur == "0"
    -> Error(ParseError(str))
    "0" as n <> rest
    | "1" as n <> rest
    | "2" as n <> rest
    | "3" as n <> rest
    | "4" as n <> rest
    | "5" as n <> rest
    | "6" as n <> rest
    | "7" as n <> rest
    | "8" as n <> rest
    | "9" as n <> rest -> get_next_int(rest, cur <> n)
    _ -> {
      case validate_int(cur) {
        Error(e) -> Error(e)
        Ok(i) -> Ok(#(i, str))
      }
    }
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
    Error(_) -> Error(ParseError(str))
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
  LogicalExpression(LogicalOrExpression)
}

pub type LogicalAndExpression {
  LogicalAndExpression(List(Expression))
}

pub type LogicalOrExpression {
  LogicalOrExpression(List(LogicalAndExpression))
}

pub type Comparable

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
  Function(Function)
}

pub type Filter {
  Relative(path: JsonPath)
  Root(path: JsonPath)
}

pub type Function

pub type FunctionArgument

pub type Expression {
  Paren(expr: LogicalExpression, not: Bool)
  Comparison(cmp1: Comparable, cmp2: Comparable, cmpop: CompareOp)
  Test(expr: TestExpression, not: Bool)
}
