import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import gleam/string
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, InvalidCharacter, InvalidEscapeCharacter,
  InvalidHex, InvalidNumber, JsonArray, JsonBool, JsonNull, JsonNumber,
  JsonObject, JsonString, NestingDepth, UnexpectedCharacter, UnexpectedEnd,
  Unknown,
}

const max_depth = 512

pub fn parse(json: String) -> Result(JsonValue, ParseError) {
  let json = do_trim_whitespace(json)
  case do_parse(json, 0) {
    Ok(#(rest, json_value)) -> {
      let rest = do_trim_whitespace(rest)
      case rest {
        "" -> Ok(json_value)
        _ -> Error(create_error(UnexpectedCharacter, json, rest, ""))
      }
    }
    Error(UnexpectedCharacter(char, rest, -1)) -> {
      Error(create_error(UnexpectedCharacter, json, rest, char))
    }
    Error(InvalidNumber(num, rest, -1)) -> {
      Error(create_error(InvalidNumber, json, rest, num))
    }
    Error(InvalidCharacter(char, rest, -1)) -> {
      Error(create_error(InvalidCharacter, json, rest, char))
    }
    Error(InvalidHex(hex, rest, -1)) -> {
      Error(create_error(InvalidHex, json, rest, hex))
    }
    Error(InvalidEscapeCharacter(esc_char, rest, -1)) -> {
      Error(create_error(InvalidEscapeCharacter, json, rest, esc_char))
    }
    Error(_ as parse_error) -> Error(parse_error)
  }
}

fn create_error(
  constructor: fn(String, String, Int) -> ParseError,
  json: String,
  rest: String,
  char: String,
) -> ParseError {
  let assert Ok(first_char) = case char {
    "" -> string.first(rest)
    _ -> Ok(char)
  }
  let assert Ok(#(initial_str, _)) =
    string.split_once(json <> "\u{00}", rest <> "\u{00}")
  constructor(first_char, rest, string.length(initial_str))
}

fn do_parse(
  json: String,
  current_depth: Int,
) -> Result(#(String, JsonValue), ParseError) {
  let json = do_trim_whitespace(json)
  case json {
    "[" <> rest -> {
      do_parse_list(rest, [], None, current_depth + 1)
    }
    "{" <> rest -> {
      do_parse_object(rest, dict.new(), None, current_depth + 1)
    }
    "\"" <> rest -> {
      do_parse_string(rest, "")
    }
    "true" <> rest -> {
      Ok(#(rest, JsonBool(True)))
    }
    "false" <> rest -> {
      Ok(#(rest, JsonBool(False)))
    }
    "null" <> rest -> {
      Ok(#(rest, JsonNull))
    }
    "-" <> _rest
    | "0" <> _rest
    | "1" <> _rest
    | "2" <> _rest
    | "3" <> _rest
    | "4" <> _rest
    | "5" <> _rest
    | "6" <> _rest
    | "7" <> _rest
    | "8" <> _rest
    | "9" <> _rest -> {
      do_parse_number(json)
    }
    "" -> Error(UnexpectedEnd)
    _ -> Error(UnexpectedCharacter("", json, -1))
  }
}

fn do_trim_whitespace(json: String) -> String {
  case json {
    " " <> rest | "\r" <> rest | "\n" <> rest | "\t" <> rest ->
      do_trim_whitespace(rest)
    _ -> json
  }
}

fn do_parse_object(
  json: String,
  obj: Dict(String, JsonValue),
  last_entry: Option(#(Option(Nil), Option(String), Option(JsonValue))),
  current_depth: Int,
) -> Result(#(String, JsonValue), ParseError) {
  use <- bool.guard(
    when: current_depth > max_depth,
    return: Error(NestingDepth(current_depth)),
  )
  let trimmed_json = do_trim_whitespace(json)
  case trimmed_json {
    "}" <> rest -> {
      case last_entry {
        None | Some(#(None, None, None)) -> Ok(#(rest, JsonObject(obj)))
        _ -> Error(UnexpectedCharacter("}", trimmed_json, -1))
      }
    }
    "\"" <> rest -> {
      case last_entry {
        None | Some(#(Some(Nil), None, None)) -> {
          case do_parse_string(rest, "") {
            Ok(#(rest, JsonString(key))) ->
              do_parse_object(
                rest,
                obj,
                Some(#(Some(Nil), Some(key), None)),
                current_depth,
              )
            Error(e) -> Error(e)
            Ok(_) -> Error(Unknown)
          }
        }
        _ -> Error(UnexpectedCharacter("\"", trimmed_json, -1))
      }
    }
    ":" <> rest -> {
      case last_entry {
        Some(#(Some(Nil), Some(key), None)) -> {
          use #(rest, value) <- result.try(do_parse(rest, current_depth))
          do_parse_object(
            rest,
            dict.insert(obj, key, value),
            Some(#(None, None, None)),
            current_depth,
          )
        }
        _ -> Error(UnexpectedCharacter(":", trimmed_json, -1))
      }
    }
    "," <> rest -> {
      case last_entry {
        Some(#(None, None, None)) -> {
          do_parse_object(
            rest,
            obj,
            Some(#(Some(Nil), None, None)),
            current_depth,
          )
        }
        _ -> Error(UnexpectedCharacter(",", trimmed_json, -1))
      }
    }
    "" -> Error(UnexpectedEnd)
    _ -> Error(UnexpectedCharacter("", trimmed_json, -1))
  }
}

fn do_parse_string(
  json: String,
  str: String,
) -> Result(#(String, JsonValue), ParseError) {
  case json {
    "\"" <> rest -> Ok(#(rest, JsonString(str)))
    "\\" <> rest -> {
      case rest {
        "\"" <> rest -> do_parse_string(rest, str <> "\"")
        "\\" <> rest -> do_parse_string(rest, str <> "\\")
        "/" <> rest -> do_parse_string(rest, str <> "/")
        "b" <> rest -> do_parse_string(rest, str <> "\u{08}")
        "f" <> rest -> do_parse_string(rest, str <> "\f")
        "n" <> rest -> do_parse_string(rest, str <> "\n")
        "r" <> rest -> do_parse_string(rest, str <> "\r")
        "t" <> rest -> do_parse_string(rest, str <> "\t")
        "u" <> rest -> {
          use #(rest, char) <- result.try(parse_hex(rest))
          do_parse_string(rest, str <> char)
        }
        "" -> Error(UnexpectedEnd)
        _ -> {
          let assert Ok(first_char) = string.first(rest)
          Error(InvalidEscapeCharacter(first_char, json, -1))
        }
      }
    }
    "\u{00}" <> _
    | "\u{01}" <> _
    | "\u{02}" <> _
    | "\u{03}" <> _
    | "\u{04}" <> _
    | "\u{05}" <> _
    | "\u{06}" <> _
    | "\u{07}" <> _
    | "\u{08}" <> _
    | "\u{09}" <> _
    | "\u{0A}" <> _
    | "\u{0B}" <> _
    | "\u{0C}" <> _
    | "\u{0D}" <> _
    | "\u{0E}" <> _
    | "\u{0F}" <> _
    | "\u{10}" <> _
    | "\u{11}" <> _
    | "\u{12}" <> _
    | "\u{13}" <> _
    | "\u{14}" <> _
    | "\u{15}" <> _
    | "\u{16}" <> _
    | "\u{17}" <> _
    | "\u{18}" <> _
    | "\u{19}" <> _
    | "\u{1A}" <> _
    | "\u{1B}" <> _
    | "\u{1C}" <> _
    | "\u{1D}" <> _
    | "\u{1E}" <> _
    | "\u{1F}" <> _ -> {
      let assert Ok(first_char) = string.first(json)
      Error(InvalidCharacter(first_char, json, -1))
    }
    _ -> {
      use #(char, rest) <- result.try(
        string.pop_grapheme(json) |> result.map_error(fn(_) { UnexpectedEnd }),
      )
      do_parse_string(rest, str <> char)
    }
  }
}

fn parse_hex(json: String) -> Result(#(String, String), ParseError) {
  let hex = string.slice(json, 0, 4)
  use <- bool.guard(string.length(hex) < 4, return: Error(UnexpectedEnd))
  let rest = string.drop_left(json, 4)
  use parsed <- result.try(
    int.base_parse(hex, 16)
    |> result.map_error(fn(_) { InvalidHex(hex, json, -1) }),
  )
  case parsed {
    65_534 | 65_535 -> Ok(#(rest, ""))
    _ -> {
      use utf8 <- result.try(
        string.utf_codepoint(parsed)
        |> result.map_error(fn(_) { InvalidHex(hex, json, -1) }),
      )
      Ok(#(rest, string.from_utf_codepoints([utf8])))
    }
  }
}

fn do_parse_list(
  json: String,
  list: List(JsonValue),
  last_value: Option(JsonValue),
  current_depth: Int,
) -> Result(#(String, JsonValue), ParseError) {
  use <- bool.guard(
    when: current_depth > max_depth,
    return: Error(NestingDepth(current_depth)),
  )
  let trimmed_json = do_trim_whitespace(json)
  case trimmed_json {
    "]" <> rest ->
      Ok(#(rest, JsonArray(list_to_indexed_dict(list.reverse(list)))))
    "," <> rest -> {
      case last_value {
        None -> Error(InvalidCharacter(",", trimmed_json, -1))
        Some(_) -> {
          use #(rest, next_item) <- result.try(do_parse(rest, current_depth))
          do_parse_list(
            rest,
            [next_item, ..list],
            Some(next_item),
            current_depth,
          )
        }
      }
    }
    "" -> Error(UnexpectedEnd)
    _ -> {
      case last_value {
        None -> {
          use #(rest, next_item) <- result.try(do_parse(json, current_depth))
          do_parse_list(
            rest,
            [next_item, ..list],
            Some(next_item),
            current_depth,
          )
        }
        Some(_) -> Error(UnexpectedCharacter("", trimmed_json, -1))
      }
    }
  }
}

fn do_parse_number(
  original_json: String,
) -> Result(#(String, JsonValue), ParseError) {
  use #(json, num) <- result.try(case original_json {
    "-" <> rest -> {
      do_parse_int(rest, False, "-")
    }
    json -> do_parse_int(json, False, "")
  })

  use #(json, fraction) <- result.try(
    case json {
      "." <> rest -> do_parse_int(rest, True, "")
      _ -> Ok(#(json, ""))
    }
    |> result.map_error(fn(err) {
      case err {
        InvalidNumber(fraction, _, _) ->
          InvalidNumber(num <> "." <> fraction, original_json, -1)
        _ -> err
      }
    }),
  )

  use #(json, exp) <- result.try(
    case json {
      "e" <> rest | "E" <> rest -> do_parse_exponent(rest)
      _ -> Ok(#(json, ""))
    }
    |> result.map_error(fn(err) {
      case err {
        InvalidNumber(exp, _, _) -> {
          let invalid_num =
            num
            <> {
              case fraction {
                "" -> ""
                _ -> "." <> fraction
              }
            }

          InvalidNumber(invalid_num <> "e" <> exp, original_json, -1)
        }
        _ -> err
      }
    }),
  )

  let original =
    num
    <> {
      case fraction {
        "" -> ""
        _ -> "." <> fraction
      }
    }
    <> {
      case exp {
        "" -> ""
        _ -> "e" <> exp
      }
    }

  use ret <- result.try(case fraction, exp {
    "", "" -> Ok(JsonNumber(Some(decode_int(num, "", 0)), None, Some(original)))

    "", "-" <> exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.map_error(fn(_) { InvalidNumber(original, original_json, -1) }),
      )
      // Optimisation here for negative exponent where if the string ends with enough
      // zeroes we can just create an int rather than a float
      case string.ends_with(num, string.repeat("0", exp)) {
        True ->
          Ok(JsonNumber(Some(decode_int(num, "", -exp)), None, Some(original)))
        False ->
          Ok(JsonNumber(
            None,
            Some(decode_float(num, fraction, -exp)),
            Some(original),
          ))
      }
    }
    "", "+" <> exp | "", exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.map_error(fn(_) { InvalidNumber(original, original_json, -1) }),
      )
      use <- bool.guard(
        when: exp > 1_000_000,
        return: Error(InvalidNumber(original, original_json, -1)),
      )
      Ok(JsonNumber(Some(decode_int(num, "", exp)), None, Some(original)))
    }
    _, "" ->
      Ok(JsonNumber(None, Some(decode_float(num, fraction, 0)), Some(original)))
    _, "-" <> exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.map_error(fn(_) { InvalidNumber(original, original_json, -1) }),
      )
      Ok(JsonNumber(
        None,
        Some(decode_float(num, fraction, -exp)),
        Some(original),
      ))
    }
    _, "+" <> exp | _, exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.map_error(fn(_) { InvalidNumber(original, original_json, -1) }),
      )
      use <- bool.guard(
        when: exp > 1_000_000,
        return: Error(InvalidNumber(original, original_json, -1)),
      )
      let fraction_length = string.length(fraction)
      case exp >= fraction_length {
        True ->
          Ok(JsonNumber(
            Some(decode_int(num, fraction, exp)),
            None,
            Some(original),
          ))
        False ->
          Ok(JsonNumber(
            None,
            Some(decode_float(num, fraction, exp)),
            Some(original),
          ))
      }
    }
  })

  Ok(#(json, ret))
}

fn decode_int(int_val: String, fraction: String, exp: Int) -> Int {
  let assert Ok(int_val) = int.parse(int_val)
  let #(int_val, exp) = case fraction {
    "" -> #(int_val, exp)
    fraction -> {
      let fraction_length = string.length(fraction)
      let assert Ok(fraction) = int.parse(fraction)

      #(int_val * fast_exp(fraction_length) + fraction, exp - fraction_length)
    }
  }
  case exp < 0 {
    True -> {
      int_val / fast_exp(-exp)
    }
    False -> {
      int_val * fast_exp(exp)
    }
  }
}

fn fast_exp(n: Int) -> Int {
  exp2(1, 10, n)
}

fn exp2(y: Int, x: Int, n: Int) -> Int {
  case int.compare(n, 0) {
    Eq -> y
    Lt -> -999
    Gt -> {
      case int.is_even(n) {
        True -> exp2(y, x * x, n / 2)
        False -> exp2(x * y, x * x, { n - 1 } / 2)
      }
    }
  }
}

fn decode_float(int_val: String, fraction: String, exp: Int) -> Float {
  let float_val = case fraction {
    "" -> int_val <> ".0"
    _ -> int_val <> "." <> fraction
  }
  let assert Ok(float_val) = float.parse(float_val)
  case int.compare(exp, 0) {
    Eq -> float_val
    Gt -> {
      float_val *. int.to_float(fast_exp(exp))
    }
    Lt -> {
      let assert Ok(mult) = int.power(10, int.to_float(exp))

      float_val *. mult
    }
  }
}

fn do_parse_exponent(json: String) -> Result(#(String, String), ParseError) {
  use #(json, exp) <- result.try(case json {
    "+" <> rest -> do_parse_int(rest, True, "")
    "-" <> rest -> do_parse_int(rest, True, "-")
    _ -> do_parse_int(json, True, "")
  })

  Ok(#(json, exp))
}

fn do_parse_int(
  json: String,
  allow_leading_zeroes: Bool,
  num: String,
) -> Result(#(String, String), ParseError) {
  case json {
    "0" as n <> rest
    | "1" as n <> rest
    | "2" as n <> rest
    | "3" as n <> rest
    | "4" as n <> rest
    | "5" as n <> rest
    | "6" as n <> rest
    | "7" as n <> rest
    | "8" as n <> rest
    | "9" as n <> rest -> {
      do_parse_int(rest, allow_leading_zeroes, num <> n)
    }
    _ -> {
      case num {
        "" | "-" -> {
          Error(InvalidNumber(
            num
              <> {
              case string.first(json) {
                Ok(char) -> char
                _ -> ""
              }
            },
            num <> json,
            -1,
          ))
        }
        _ -> {
          case allow_leading_zeroes || num == "0" || num == "-0" {
            True -> Ok(#(json, num))
            False -> {
              case
                string.starts_with(num, "0") || string.starts_with(num, "-0")
              {
                True -> Error(InvalidNumber(num, num <> json, -1))
                False -> Ok(#(json, num))
              }
            }
          }
        }
      }
    }
  }
}

fn list_to_indexed_dict(initial_list: List(a)) -> Dict(Int, a) {
  use current_dict, item, index <- list.index_fold(initial_list, dict.new())
  dict.insert(current_dict, index, item)
}
