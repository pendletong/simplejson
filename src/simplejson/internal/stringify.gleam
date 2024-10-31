import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub fn to_string(json: JsonValue) -> String {
  create_string(json, "")
}

fn create_string(json: JsonValue, acc: String) -> String {
  case json {
    JsonBool(b) -> {
      case b {
        True -> acc <> "true"
        False -> acc <> "false"
      }
    }
    JsonString(s) -> {
      acc <> "\"" <> encode_string(s, "") <> "\""
    }
    JsonArray(l) -> acc <> "[" <> encode_list(dict.values(l), "") <> "]"
    JsonNull -> acc <> "null"
    JsonNumber(_, _, Some(s)) -> acc <> s
    JsonNumber(Some(i), _, _) -> acc <> encode_int(i)
    JsonNumber(_, Some(f), _) -> acc <> encode_float(f)
    JsonNumber(None, None, _) -> panic
    JsonObject(o) -> acc <> "{" <> encode_object(o) <> "}"
  }
}

fn encode_int(n: Int) -> String {
  int.to_string(n)
}

fn encode_float(n: Float) -> String {
  float.to_string(n)
}

fn encode_object(o: Dict(String, JsonValue)) -> String {
  encode_object_elements(dict.keys(o), o, "")
}

fn encode_object_elements(
  keys: List(String),
  o: Dict(String, JsonValue),
  acc: String,
) -> String {
  case keys {
    [key, ..rest] -> {
      let assert Ok(value) = dict.get(o, key)
      encode_object_elements(
        rest,
        o,
        acc
          <> {
          case acc {
            "" -> ""
            _ -> ","
          }
        }
          <> "\""
          <> encode_string(key, "")
          <> "\":"
          <> create_string(value, ""),
      )
    }
    [] -> acc
  }
}

fn encode_string(str: String, acc: String) -> String {
  case string.pop_grapheme(str) {
    Ok(#(char, rest)) -> encode_string(rest, acc <> encode_char(char))
    Error(_) -> acc
  }
}

fn encode_char(char: String) -> String {
  case char {
    "\r\n" -> "\\r\\n"
    "\u{00}" -> "\\u0000"
    "\u{01}" -> "\\u0001"
    "\u{02}" -> "\\u0002"
    "\u{03}" -> "\\u0003"
    "\u{04}" -> "\\u0004"
    "\u{05}" -> "\\u0005"
    "\u{06}" -> "\\u0006"
    "\u{07}" -> "\\u0007"
    "\u{08}" -> "\\b"
    "\u{09}" -> "\\t"
    "\u{0A}" -> "\\n"
    "\u{0B}" -> "\\u000B"
    "\u{0C}" -> "\\f"
    "\u{0D}" -> "\\r"
    "\u{0E}" -> "\\u000E"
    "\u{0F}" -> "\\u000F"
    "\u{10}" -> "\\u0010"
    "\u{11}" -> "\\u0011"
    "\u{12}" -> "\\u0012"
    "\u{13}" -> "\\u0013"
    "\u{14}" -> "\\u0014"
    "\u{15}" -> "\\u0015"
    "\u{16}" -> "\\u0016"
    "\u{17}" -> "\\u0017"
    "\u{18}" -> "\\u0018"
    "\u{19}" -> "\\u0019"
    "\u{1A}" -> "\\u001A"
    "\u{1B}" -> "\\u001B"
    "\u{1C}" -> "\\u001C"
    "\u{1D}" -> "\\u001D"
    "\u{1E}" -> "\\u001E"
    "\u{1F}" -> "\\u001F"
    "\"" -> "\\\""
    "\\" -> "\\\\"
    _ -> char
  }
}

fn encode_list(l: List(JsonValue), acc: String) -> String {
  case l {
    [JsonArray(_) as el, ..rest]
    | [JsonBool(_) as el, ..rest]
    | [JsonNull as el, ..rest]
    | [JsonObject(_) as el, ..rest]
    | [JsonString(_) as el, ..rest]
    | [JsonNumber(_, _, _) as el, ..rest] -> {
      encode_list(
        rest,
        acc
          <> {
          case acc {
            "" -> ""
            _ -> ","
          }
        }
          <> create_string(el, ""),
      )
    }
    [] -> acc
  }
}
