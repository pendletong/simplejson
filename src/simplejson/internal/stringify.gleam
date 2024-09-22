import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/option.{None, Some}
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
    JsonArray(l) -> acc <> "[" <> encode_list(l, "") <> "]"
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
  str
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
