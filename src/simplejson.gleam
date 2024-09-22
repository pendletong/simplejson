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

pub fn main() {
  parse(
    //"{  \"type\": \"FeatureCollection\",  \"features\": [    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Point\",        \"coordinates\": [4.483605784808901, 51.907188449679325]      }    },    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Polygon\",        \"coordinates\": [          [            [3.974369110811523 , 51.907355547778565],            [4.173944459020191 , 51.86237166892457 ],            [4.3808076710679416, 51.848867725914914],            [4.579822414365026 , 51.874487141880024],            [4.534413416598767 , 51.9495302480326  ],            [4.365110733567974 , 51.92360787140825 ],            [4.179550508127079 , 51.97336560819281 ],            [4.018096293847009 , 52.00236546429852 ],            [3.9424146309028174, 51.97681895676649 ],            [3.974369110811523 , 51.907355547778565]          ]        ]      }}]}",
    // "[123123e100000]",
    // "[1.2e2,1.2e3,1.2e4,1.32423e7, 123000e-2]",
    "[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]",
  )
  |> io.debug
}

pub type JsonValue {
  JsonString(str: String)
  JsonNumber(int: Option(Int), float: Option(Float))
  JsonBool(bool: Bool)
  JsonNull
  JsonArray(List(JsonValue))
  JsonObject(Dict(String, JsonValue))
}

pub fn parse(json: String) -> Result(JsonValue, Nil) {
  case do_parse(json) {
    Ok(#(rest, json_value)) -> {
      case check_end(rest) {
        False -> Error(Nil)
        True -> Ok(json_value)
      }
    }
    _ -> Error(Nil)
  }
}

fn check_end(json: String) -> Bool {
  case json {
    " " <> rest | "\r" <> rest | "\n" <> rest | "\t" <> rest -> check_end(rest)
    "" -> True
    _ -> False
  }
}

fn do_parse(json: String) -> Result(#(String, JsonValue), Nil) {
  let json = do_trim_whitespace(json)
  case json {
    "[" <> rest -> {
      do_parse_list(rest, [], None)
    }
    "{" <> rest -> {
      do_parse_object(rest, dict.new(), None)
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

    _ -> Error(Nil)
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
) -> Result(#(String, JsonValue), Nil) {
  case do_trim_whitespace(json) {
    "}" <> rest -> {
      case last_entry {
        None | Some(#(None, None, None)) -> Ok(#(rest, JsonObject(obj)))
        _ -> Error(Nil)
      }
    }
    "\"" <> rest -> {
      case last_entry {
        None | Some(#(Some(Nil), None, None)) -> {
          case do_parse_string(rest, "") {
            Ok(#(rest, JsonString(key))) ->
              do_parse_object(rest, obj, Some(#(Some(Nil), Some(key), None)))
            _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    ":" <> rest -> {
      case last_entry {
        Some(#(Some(Nil), Some(key), None)) -> {
          use #(rest, value) <- result.try(do_parse(rest))
          do_parse_object(
            rest,
            dict.insert(obj, key, value),
            Some(#(None, None, None)),
          )
        }
        _ -> Error(Nil)
      }
    }
    "," <> rest -> {
      case last_entry {
        Some(#(None, None, None)) -> {
          do_parse_object(rest, obj, Some(#(Some(Nil), None, None)))
        }
        _ -> Error(Nil)
      }
    }
    _ -> {
      Error(Nil)
    }
  }
}

fn do_parse_string(
  json: String,
  str: String,
) -> Result(#(String, JsonValue), Nil) {
  use #(char, rest) <- result.try(string.pop_grapheme(json))
  case char {
    "\"" -> Ok(#(rest, JsonString(str)))
    "\\" -> {
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
        _ -> Error(Nil)
      }
    }
    _ -> {
      case string.to_utf_codepoints(char) {
        [n] -> {
          case string.utf_codepoint_to_int(n) < 32 {
            True -> Error(Nil)
            False -> do_parse_string(rest, str <> char)
          }
        }
        _ -> Error(Nil)
      }
    }
  }
}

fn parse_hex(json: String) -> Result(#(String, String), Nil) {
  let hex = string.slice(json, 0, 4)
  use <- bool.guard(string.length(hex) < 4, return: Error(Nil))
  let rest = string.drop_left(json, 4)
  use parsed <- result.try(int.base_parse(hex, 16))
  case parsed {
    65_534 | 65_535 -> Ok(#(rest, ""))
    _ -> {
      use utf8 <- result.try(string.utf_codepoint(parsed))
      Ok(#(rest, string.from_utf_codepoints([utf8])))
    }
  }
}

fn do_parse_list(
  json: String,
  list: List(JsonValue),
  last_value: Option(JsonValue),
) -> Result(#(String, JsonValue), Nil) {
  case do_trim_whitespace(json) {
    "]" <> rest -> Ok(#(rest, JsonArray(list.reverse(list))))
    "," <> rest -> {
      case last_value {
        None -> Error(Nil)
        Some(_) -> {
          use #(rest, next_item) <- result.try(do_parse(rest))
          do_parse_list(rest, [next_item, ..list], Some(next_item))
        }
      }
    }
    _ -> {
      case last_value {
        None -> {
          use #(rest, next_item) <- result.try(do_parse(json))
          do_parse_list(rest, [next_item, ..list], Some(next_item))
        }
        Some(_) -> Error(Nil)
      }
    }
  }
}

fn do_parse_number(json: String) -> Result(#(String, JsonValue), Nil) {
  use #(json, num) <- result.try(case json {
    "-" <> rest -> {
      do_parse_int(rest, False, "-")
    }
    _ -> do_parse_int(json, False, "")
  })

  use #(json, fraction) <- result.try(case json {
    "." <> rest -> do_parse_int(rest, True, "")
    _ -> Ok(#(json, ""))
  })

  use #(json, exp) <- result.try(case json {
    "e" <> rest | "E" <> rest -> do_parse_exponent(rest)
    _ -> Ok(#(json, ""))
  })

  let ret = case fraction {
    "" -> {
      case exp {
        "" -> JsonNumber(Some(decode_int(num, "", 0)), None)

        "-" <> exp -> {
          let assert Ok(exp) = int.parse(exp)
          case string.ends_with(num, string.repeat("0", exp)) {
            True -> JsonNumber(Some(decode_int(num, "", -exp)), None)
            False -> JsonNumber(None, Some(decode_float(num, fraction, -exp)))
          }
        }
        "+" <> exp | exp -> {
          let assert Ok(exp) = int.parse(exp)
          JsonNumber(Some(decode_int(num, "", exp)), None)
        }
      }
    }
    _ -> {
      case exp {
        "" -> JsonNumber(None, Some(decode_float(num, fraction, 0)))
        "-" <> exp -> {
          let assert Ok(exp) = int.parse(exp)
          JsonNumber(None, Some(decode_float(num, fraction, -exp)))
        }
        "+" <> exp | exp -> {
          let assert Ok(exp) = int.parse(exp)
          let fraction_length = string.length(fraction)
          case exp >= fraction_length {
            True -> JsonNumber(Some(decode_int(num, fraction, exp)), None)
            False -> JsonNumber(None, Some(decode_float(num, fraction, exp)))
          }
        }
      }
    }
  }

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
  let assert Ok(mult) = int.power(10, int.to_float(exp))

  float_val *. mult
}

fn do_parse_exponent(json: String) -> Result(#(String, String), Nil) {
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
) -> Result(#(String, String), Nil) {
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
      case num, allow_leading_zeroes {
        "0", False | "-0", False -> Error(Nil)
        _, _ -> do_parse_int(rest, allow_leading_zeroes, num <> n)
      }
    }
    _ -> {
      case num {
        "" | "-" -> Error(Nil)
        _ -> Ok(#(json, num))
      }
    }
  }
}
// fn parse_array(json: String, acc: JsonValue) -> JsonValue {

// }
