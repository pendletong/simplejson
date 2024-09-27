import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import gleam/string
import simplejson/jsonvalue.{
  type JsonValue, type ParseError, InvalidCharacter, InvalidEscapeCharacter,
  InvalidFloat, InvalidHex, InvalidInt, InvalidNumber, JsonArray, JsonBool,
  JsonMetaData, JsonNull, JsonNumber, JsonObject, JsonString, NestingDepth,
  UnexpectedCharacter, UnexpectedEnd, Unknown,
}

const max_depth = 512

type Location {
  Location(depth: Int, char: Int, block_start: Int)
}

type ReturnInfo {
  ReturnInfo(remaining: String, json: JsonValue, location: Location)
}

pub fn parse(json: String) -> Result(JsonValue, ParseError) {
  let #(json, current_loc) = do_trim_whitespace(json, Location(0, 0, 0))
  case do_parse(json, current_loc) {
    Ok(ReturnInfo(rest, json_value, current_loc)) -> {
      let #(rest, _) = do_trim_whitespace(rest, current_loc)
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
  let start_pos = string.length(initial_str)
  constructor(
    first_char,
    string.slice(
      json,
      int.max(0, start_pos - 5),
      int.min(string.length(json), start_pos + 5),
    ),
    start_pos,
  )
}

fn increment_location(loc: Location, pos: Int, depth: Int) -> Location {
  Location(loc.depth + depth, loc.char + pos, loc.block_start)
}

fn increment_location_and_mark_start(
  loc: Location,
  pos: Int,
  depth: Int,
) -> Location {
  Location(loc.depth + depth, loc.char + pos, loc.char)
}

fn unpop_start(return_info: ReturnInfo, original_pos: Location) {
  let new_location =
    Location(..return_info.location, block_start: original_pos.block_start)
  ReturnInfo(..return_info, location: new_location)
}

fn unpop_depth(return_info: ReturnInfo, original_pos: Location) {
  let new_location = Location(..return_info.location, depth: original_pos.depth)
  ReturnInfo(..return_info, location: new_location)
}

fn do_parse(
  json: String,
  original_pos: Location,
) -> Result(ReturnInfo, ParseError) {
  let #(json, current_pos) = do_trim_whitespace(json, original_pos)
  case json {
    "[" <> rest -> {
      do_parse_list(
        rest,
        [],
        None,
        increment_location_and_mark_start(current_pos, 1, 1),
      )
      |> result.map(unpop_start(_, original_pos))
      |> result.map(unpop_depth(_, original_pos))
    }
    "{" <> rest -> {
      do_parse_object(
        rest,
        dict.new(),
        None,
        increment_location_and_mark_start(current_pos, 1, 1),
      )
      |> result.map(unpop_start(_, original_pos))
      |> result.map(unpop_depth(_, original_pos))
    }
    "\"" <> rest -> {
      do_parse_string(
        rest,
        "",
        increment_location_and_mark_start(current_pos, 1, 0),
      )
      |> result.map(unpop_start(_, original_pos))
    }
    "true" <> rest -> {
      Ok(ReturnInfo(
        rest,
        JsonBool(JsonMetaData(current_pos.char, current_pos.char + 4), True),
        increment_location(current_pos, 4, 0),
      ))
    }
    "false" <> rest -> {
      Ok(ReturnInfo(
        rest,
        JsonBool(JsonMetaData(current_pos.char, current_pos.char + 5), False),
        increment_location(current_pos, 5, 0),
      ))
    }
    "null" <> rest -> {
      Ok(ReturnInfo(
        rest,
        JsonNull(JsonMetaData(current_pos.char, current_pos.char + 4)),
        increment_location(current_pos, 4, 0),
      ))
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
      do_parse_number(json, current_pos)
    }
    "" -> Error(UnexpectedEnd)
    _ -> Error(UnexpectedCharacter("", json, -1))
  }
}

fn do_trim_whitespace(
  json: String,
  current_pos: Location,
) -> #(String, Location) {
  case json {
    " " <> rest | "\r" <> rest | "\n" <> rest | "\t" <> rest ->
      do_trim_whitespace(rest, increment_location(current_pos, 1, 0))
    _ -> #(json, current_pos)
  }
}

fn do_parse_object(
  json: String,
  obj: Dict(String, JsonValue),
  last_entry: Option(#(Option(Nil), Option(String), Option(JsonValue))),
  current_pos: Location,
) -> Result(ReturnInfo, ParseError) {
  use <- bool.guard(
    when: current_pos.depth > max_depth,
    return: Error(NestingDepth(current_pos.depth)),
  )
  let #(trimmed_json, current_pos) = do_trim_whitespace(json, current_pos)
  case trimmed_json {
    "}" <> rest -> {
      case last_entry {
        None | Some(#(None, None, None)) -> {
          let current_pos = increment_location(current_pos, 1, 0)
          Ok(ReturnInfo(
            rest,
            JsonObject(
              JsonMetaData(current_pos.block_start, current_pos.char),
              obj,
            ),
            current_pos,
          ))
        }
        _ -> Error(UnexpectedCharacter("}", trimmed_json, -1))
      }
    }
    "\"" <> rest -> {
      case last_entry {
        None | Some(#(Some(Nil), None, None)) -> {
          case
            do_parse_string(rest, "", increment_location(current_pos, 1, 0))
          {
            Ok(ReturnInfo(rest, JsonString(_, key), loc)) ->
              do_parse_object(
                rest,
                obj,
                Some(#(Some(Nil), Some(key), None)),
                loc,
              )
            Error(e) -> Error(e)
            Ok(_) -> {
              Error(Unknown)
            }
          }
        }
        _ -> Error(UnexpectedCharacter("\"", trimmed_json, -1))
      }
    }
    ":" <> rest -> {
      case last_entry {
        Some(#(Some(Nil), Some(key), None)) -> {
          use ReturnInfo(rest, value, pos) <- result.try(do_parse(
            rest,
            increment_location(current_pos, 1, 0),
          ))
          do_parse_object(
            rest,
            dict.insert(obj, key, value),
            Some(#(None, None, None)),
            pos,
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
            increment_location(current_pos, 1, 0),
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
  current_pos: Location,
) -> Result(ReturnInfo, ParseError) {
  case json {
    "\"" <> rest -> {
      let current_pos = increment_location(current_pos, 1, 0)
      Ok(ReturnInfo(
        rest,
        JsonString(JsonMetaData(current_pos.block_start, current_pos.char), str),
        current_pos,
      ))
    }
    "\\" <> rest -> {
      case rest {
        "\"" <> rest ->
          do_parse_string(
            rest,
            str <> "\"",
            increment_location(current_pos, 2, 0),
          )
        "\\" <> rest ->
          do_parse_string(
            rest,
            str <> "\\",
            increment_location(current_pos, 2, 0),
          )
        "/" <> rest ->
          do_parse_string(
            rest,
            str <> "/",
            increment_location(current_pos, 2, 0),
          )
        "b" <> rest ->
          do_parse_string(
            rest,
            str <> "\u{08}",
            increment_location(current_pos, 2, 0),
          )
        "f" <> rest ->
          do_parse_string(
            rest,
            str <> "\f",
            increment_location(current_pos, 2, 0),
          )
        "n" <> rest ->
          do_parse_string(
            rest,
            str <> "\n",
            increment_location(current_pos, 2, 0),
          )
        "r" <> rest ->
          do_parse_string(
            rest,
            str <> "\r",
            increment_location(current_pos, 2, 0),
          )
        "t" <> rest ->
          do_parse_string(
            rest,
            str <> "\t",
            increment_location(current_pos, 2, 0),
          )
        "u" <> rest -> {
          use #(rest, char) <- result.try(parse_hex(rest))
          do_parse_string(
            rest,
            str <> char,
            increment_location(current_pos, 6, 0),
          )
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
      do_parse_string(rest, str <> char, increment_location(current_pos, 1, 0))
    }
  }
}

fn parse_hex(json: String) -> Result(#(String, String), ParseError) {
  let hex = string.slice(json, 0, 4)
  use <- bool.guard(string.length(hex) < 4, return: Error(UnexpectedEnd))
  let rest = string.drop_start(json, 4)
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
  current_pos: Location,
) -> Result(ReturnInfo, ParseError) {
  use <- bool.guard(
    when: current_pos.depth > max_depth,
    return: Error(NestingDepth(current_pos.depth)),
  )
  let #(trimmed_json, current_pos) = do_trim_whitespace(json, current_pos)
  case trimmed_json {
    "]" <> rest -> {
      let current_pos = increment_location(current_pos, 1, 0)
      Ok(ReturnInfo(
        rest,
        JsonArray(
          JsonMetaData(current_pos.block_start, current_pos.char),
          list_to_indexed_dict(list.reverse(list)),
        ),
        current_pos,
      ))
    }
    "," <> rest -> {
      case last_value {
        None -> Error(InvalidCharacter(",", trimmed_json, -1))
        Some(_) -> {
          use ReturnInfo(rest, next_item, current_pos) <- result.try(do_parse(
            rest,
            increment_location(current_pos, 1, 0),
          ))
          do_parse_list(rest, [next_item, ..list], Some(next_item), current_pos)
        }
      }
    }
    "" -> Error(UnexpectedEnd)
    _ -> {
      case last_value {
        None -> {
          use ReturnInfo(rest, next_item, current_pos) <- result.try(do_parse(
            trimmed_json,
            current_pos,
          ))
          do_parse_list(rest, [next_item, ..list], Some(next_item), current_pos)
        }
        Some(_) -> Error(UnexpectedCharacter("", trimmed_json, -1))
      }
    }
  }
}

fn do_parse_number(
  original_json: String,
  current_pos: Location,
) -> Result(ReturnInfo, ParseError) {
  let original_pos = current_pos
  use #(json, num, current_pos) <- result.try(case original_json {
    "-" <> rest -> {
      do_parse_int(rest, False, "-", increment_location(current_pos, 1, 0))
    }
    json -> do_parse_int(json, False, "", current_pos)
  })

  use #(json, fraction, current_pos) <- result.try(
    case json {
      "." <> rest ->
        do_parse_int(rest, True, "", increment_location(current_pos, 1, 0))
      _ -> Ok(#(json, "", current_pos))
    }
    |> result.map_error(fn(err) {
      case err {
        InvalidNumber(fraction, _, _) ->
          InvalidNumber(num <> "." <> fraction, original_json, -1)
        _ -> err
      }
    }),
  )

  use #(json, exp, current_pos) <- result.try(
    case json {
      "e" <> rest | "E" <> rest ->
        do_parse_exponent(rest, increment_location(current_pos, 1, 0))
      _ -> Ok(#(json, "", current_pos))
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
    "", "" -> {
      use i <- result.try(decode_int(num, "", 0))
      Ok(JsonNumber(
        JsonMetaData(original_pos.char, current_pos.char),
        Some(i),
        None,
        Some(original),
      ))
    }
    "", "-" <> exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.map_error(fn(_) { InvalidNumber(original, original_json, -1) }),
      )
      // Optimisation here for negative exponent where if the string ends with enough
      // zeroes we can just create an int rather than a float
      case string.ends_with(num, string.repeat("0", exp)) {
        True -> {
          use i <- result.try(decode_int(num, "", -exp))
          Ok(JsonNumber(
            JsonMetaData(original_pos.char, current_pos.char),
            Some(i),
            None,
            Some(original),
          ))
        }
        False -> {
          use f <- result.try(decode_float(num, fraction, -exp))
          Ok(JsonNumber(
            JsonMetaData(original_pos.char, current_pos.char),
            None,
            Some(f),
            Some(original),
          ))
        }
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
      use i <- result.try(decode_int(num, "", exp))
      Ok(JsonNumber(
        JsonMetaData(original_pos.char, current_pos.char),
        Some(i),
        None,
        Some(original),
      ))
    }
    _, "" -> {
      use f <- result.try(decode_float(num, fraction, 0))
      Ok(JsonNumber(
        JsonMetaData(original_pos.char, current_pos.char),
        None,
        Some(f),
        Some(original),
      ))
    }
    _, "-" <> exp -> {
      use exp <- result.try(
        int.parse(exp)
        |> result.replace_error(InvalidNumber(original, original_json, -1)),
      )
      use f <- result.try(decode_float(num, fraction, -exp))
      Ok(JsonNumber(
        JsonMetaData(original_pos.char, current_pos.char),
        None,
        Some(f),
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
        True -> {
          use i <- result.try(decode_int(num, fraction, exp))
          Ok(JsonNumber(
            JsonMetaData(original_pos.char, current_pos.char),
            Some(i),
            None,
            Some(original),
          ))
        }
        False -> {
          use f <- result.try(decode_float(num, fraction, exp))
          Ok(JsonNumber(
            JsonMetaData(original_pos.char, current_pos.char),
            None,
            Some(f),
            Some(original),
          ))
        }
      }
    }
  })

  Ok(ReturnInfo(json, ret, current_pos))
}

fn decode_int(
  int_val: String,
  fraction: String,
  exp: Int,
) -> Result(Int, ParseError) {
  use int_val <- result.try(
    int.parse(int_val) |> result.replace_error(InvalidInt(int_val)),
  )
  use #(int_val, exp) <- result.try(case fraction {
    "" -> Ok(#(int_val, exp))
    fraction -> {
      let fraction_length = string.length(fraction)
      use fraction <- result.try(
        int.parse(fraction) |> result.replace_error(InvalidInt(fraction)),
      )

      Ok(#(
        int_val * fast_exp(fraction_length) + fraction,
        exp - fraction_length,
      ))
    }
  })
  case exp < 0 {
    True -> {
      int_val / fast_exp(-exp)
    }
    False -> {
      int_val * fast_exp(exp)
    }
  }
  |> Ok
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

fn decode_float(
  int_val: String,
  fraction: String,
  exp: Int,
) -> Result(Float, ParseError) {
  let float_val = case fraction {
    "" -> int_val <> ".0"
    _ -> int_val <> "." <> fraction
  }
  use float_val <- result.try(
    float.parse(float_val) |> result.replace_error(InvalidFloat(float_val)),
  )
  case int.compare(exp, 0) {
    Eq -> Ok(float_val)
    Gt -> {
      Ok(float_val *. int.to_float(fast_exp(exp)))
    }
    Lt -> {
      use mult <- result.try(
        int.power(10, int.to_float(exp)) |> result.replace_error(Unknown),
      )

      Ok(float_val *. mult)
    }
  }
}

fn do_parse_exponent(
  json: String,
  current_pos: Location,
) -> Result(#(String, String, Location), ParseError) {
  use #(json, exp, current_pos) <- result.try(case json {
    "+" <> rest ->
      do_parse_int(rest, True, "", increment_location(current_pos, 1, 0))
    "-" <> rest ->
      do_parse_int(rest, True, "-", increment_location(current_pos, 1, 0))
    _ -> do_parse_int(json, True, "", current_pos)
  })

  Ok(#(json, exp, current_pos))
}

fn do_parse_int(
  json: String,
  allow_leading_zeroes: Bool,
  num: String,
  current_pos: Location,
) -> Result(#(String, String, Location), ParseError) {
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
      do_parse_int(
        rest,
        allow_leading_zeroes,
        num <> n,
        increment_location(current_pos, 1, 0),
      )
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
            True -> Ok(#(json, num, current_pos))
            False -> {
              case
                string.starts_with(num, "0") || string.starts_with(num, "-0")
              {
                True -> Error(InvalidNumber(num, num <> json, -1))
                False -> Ok(#(json, num, current_pos))
              }
            }
          }
        }
      }
    }
  }
}

pub fn list_to_indexed_dict(initial_list: List(a)) -> Dict(Int, a) {
  use current_dict, item, index <- list.index_fold(initial_list, dict.new())
  dict.insert(current_dict, index, item)
}
