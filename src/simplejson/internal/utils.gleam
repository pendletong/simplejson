import gleam/dict
import gleam/option.{type Option, None, Some}
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub fn unwrap_option_result(
  o: option.Option(Result(a, b)),
) -> Result(Option(a), b) {
  case o {
    None -> Ok(None)
    Some(Ok(n)) -> Ok(Some(n))
    Some(Error(n)) -> Error(n)
  }
}

pub fn is_object(j: JsonValue) -> Bool {
  case j {
    JsonObject(_, _) -> True
    _ -> False
  }
}

pub fn strip_metadata(json: JsonValue) -> JsonValue {
  case json {
    JsonNull(_) -> JsonNull(None)
    JsonBool(b, _) -> JsonBool(b, None)
    JsonString(s, _) -> JsonString(s, None)
    JsonNumber(i, f, _) -> JsonNumber(i, f, None)
    JsonArray(l, _) ->
      JsonArray(dict.map_values(l, fn(_k, v) { strip_metadata(v) }), None)
    JsonObject(d, _) ->
      JsonObject(dict.map_values(d, fn(_k, v) { strip_metadata(v) }), None)
  }
}
