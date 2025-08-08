import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub opaque type Selector {
  Name(name: String)
  Wildcard
  Index(i: Int)
  Slice(start: Int, end: Int, step: Int)
  Filter(expr: String)
}

pub opaque type Segment {
  Child(sels: List(Selector))
  Descendant(sels: List(Selector))
}

pub type JsonPathError {
  ParseError(context: String)
  MissingRoot
  IndexOutOfRange(i: Int)
}

const min_int = -9_007_199_254_740_991

const max_int = 9_007_199_254_740_991

pub fn parse_path(str: String) -> Result(List(Segment), JsonPathError) {
  case str {
    "$" <> rest -> {
      let trim = trim_whitespace(rest)
      case trim == "" {
        True if trim == rest -> Ok([])
        True -> Error(ParseError(str))
        False -> {
          use path <- result.try(do_parse_path(rest, []))
          Ok(path.1)
        }
      }
    }
    _ -> Error(MissingRoot)
  }
}

fn do_parse_path(
  str: String,
  content: List(Segment),
) -> Result(#(String, List(Segment)), JsonPathError) {
  let str = trim_whitespace(str)
  case str {
    "..*" <> rest -> {
      do_parse_path(rest, [Descendant([Wildcard]), ..content])
    }
    "..[" <> rest -> {
      use #(sel, rest) <- result.try(do_parse_bracketed(rest, []))
      do_parse_path(rest, [Descendant(sel), ..content])
    }
    ".." <> rest -> {
      use #(name, rest) <- result.try(do_parse_member_name(rest, ""))

      do_parse_path(rest, [Descendant([Name(name)]), ..content])
    }
    ".*" <> rest -> {
      do_parse_path(rest, [Child([Wildcard]), ..content])
    }
    "." <> rest -> {
      use #(name, rest) <- result.try(do_parse_member_name(rest, ""))

      do_parse_path(rest, [Child([Name(name)]), ..content])
    }
    "[" <> rest -> {
      use #(sel, rest) <- result.try(do_parse_bracketed(rest, []))
      do_parse_path(rest, [Child(sel), ..content])
    }
    "" -> Ok(#("", list.reverse(content)))
    _ -> Error(ParseError(str))
  }
}

fn do_parse_member_name(
  str: String,
  name: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) if name == "" -> Error(ParseError(str))
    Error(_) -> Ok(#(name, ""))
    Ok(#(ch, rest)) -> {
      case name == "" {
        True -> {
          case is_name_first(ch) {
            True -> do_parse_member_name(rest, name <> ch)
            False -> Error(ParseError(str))
          }
        }
        False -> {
          case is_name_char(ch) {
            True -> Error(ParseError(str))
            False -> do_parse_member_name(rest, name <> ch)
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
    False -> {
      case char {
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
        _ -> False
      }
    }
  }
}

fn do_parse_bracketed(
  str: String,
  sels: List(Selector),
) -> Result(#(List(Selector), String), JsonPathError) {
  let str = trim_whitespace(str)
  case str {
    "," <> rest -> {
      case sels {
        [] -> Error(ParseError(str))
        _ -> {
          use #(sel, rest) <- result.try(do_parse_selector(rest))

          do_parse_bracketed(rest, [sel, ..sels])
        }
      }
    }

    "]" <> _ if sels == [] -> Error(ParseError(str))

    "]" <> rest -> {
      Ok(#(sels, rest))
    }

    _ -> {
      use #(sel, rest) <- result.try(do_parse_selector(str))

      do_parse_bracketed(rest, [sel, ..sels])
    }
  }
}

fn do_parse_literal(
  str: String,
  quote: String,
  literal: String,
) -> Result(#(String, String), JsonPathError) {
  case string.pop_grapheme(str) {
    Error(_) -> Error(ParseError(str))
    Ok(#("\"", rest)) -> {
      case quote == "\"" {
        True -> Ok(#(literal, rest))
        False -> Error(ParseError(str))
      }
    }
    Ok(#("'", rest)) -> {
      case quote == "'" {
        True -> Ok(#(literal, rest))
        False -> Error(ParseError(str))
      }
    }
    Ok(#("\\", rest)) -> {
      case rest {
        "\"" <> _rest if quote == "'" -> Error(ParseError(str))
        "\"" <> rest -> do_parse_literal(rest, quote, literal <> "\"")
        "'" <> _rest if quote == "\"" -> Error(ParseError(str))
        "'" <> rest -> do_parse_literal(rest, quote, literal <> "'")
        "b" <> rest -> do_parse_literal(rest, quote, literal <> "\u{0008}")
        "f" <> rest -> do_parse_literal(rest, quote, literal <> "\f")
        "n" <> rest -> do_parse_literal(rest, quote, literal <> "\n")
        "r" <> rest -> do_parse_literal(rest, quote, literal <> "\r")
        "t" <> rest -> do_parse_literal(rest, quote, literal <> "\t")
        "\\" <> rest -> do_parse_literal(rest, quote, literal <> "\\")
        "/" <> rest -> do_parse_literal(rest, quote, literal <> "/")
        "u" <> rest -> {
          use #(hexchar, rest) <- result.try(do_parse_hexchar(rest))
          do_parse_literal(rest, quote, literal <> hexchar)
        }
        _ -> Error(ParseError(str))
      }
    }
    Ok(#(char, rest)) -> {
      let assert [codepoint] = string.to_utf_codepoints(char)
      let cpi = string.utf_codepoint_to_int(codepoint)
      case
        {
          case cpi {
            0x20 | 0x21 | 0x23 | 0x24 | 0x25 | 0x26 -> True
            _ if cpi >= 0x28 && cpi <= 0x5B -> True
            _ if cpi >= 0x5D && cpi <= 0xD7FF -> True
            _ if cpi >= 0xE0000 && cpi <= 0x10FFFF -> True
            _ -> False
          }
        }
      {
        True -> do_parse_literal(rest, quote, literal <> char)
        False -> Error(ParseError(str))
      }
    }
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

fn do_parse_selector(str: String) -> Result(#(Selector, String), JsonPathError) {
  let str = trim_whitespace(str)
  case str {
    "\"" as q <> rest | "'" as q <> rest -> {
      use #(name, rest) <- result.try(do_parse_literal(rest, q, ""))
      Ok(#(Name(name), rest))
    }
    "*" <> rest -> {
      Ok(#(Wildcard, rest))
    }
    "?" <> rest -> {
      todo as "Filter Selector"
    }
    "-" <> rest
    | "0" <> rest
    | "1" <> rest
    | "2" <> rest
    | "3" <> rest
    | "4" <> rest
    | "5" <> rest
    | "6" <> rest
    | "7" <> rest
    | "8" <> rest
    | "9" <> rest -> {
      do_parse_numeric_selector(str)
    }
    _ -> Error(ParseError(str))
  }
}

fn do_parse_numeric_selector(
  str: String,
) -> Result(#(Selector, String), JsonPathError) {
  use #(val1, rest) <- result.try(get_next_int(str, ""))
  let rest = trim_whitespace(rest)
  case rest {
    "]" <> _ -> Ok(#(Index(val1), rest))
    ":" <> rest -> {
      use #(val2, rest) <- result.try(get_next_int(rest, ""))
      let rest = trim_whitespace(rest)
      case rest {
        "]" <> _ -> Ok(#(Slice(val1, val2, 1), rest))
        ":" <> rest -> {
          use #(val3, rest) <- result.try(get_next_int(rest, ""))
          let rest = trim_whitespace(rest)
          case rest {
            "]" <> _ -> Ok(#(Slice(val1, val2, val3), rest))
            _ -> Error(ParseError(rest))
          }
        }
        _ -> Error(ParseError(rest))
      }
    }
    _ -> Error(ParseError(rest))
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
