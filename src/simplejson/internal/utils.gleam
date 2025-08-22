import gleam/dict
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import simplejson/internal/parser
import simplejson/internal/schema2/types.{
  type Context, type Property, type SchemaError, type Value, ArrayValue,
  InvalidProperty,
}
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

pub fn is_unique(values: List(JsonValue)) -> Bool {
  let #(unique, _) =
    list.fold_until(values, #(True, dict.new()), fn(d, v) {
      let #(_, d) = d
      case dict.has_key(d, v) {
        True -> Stop(#(False, d))
        False -> Continue(#(True, dict.insert(d, v, Nil)))
      }
    })
  unique
}

pub fn unique_strings_fn(
  v: Value,
  _c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  let assert ArrayValue(_, l) = v
  case is_unique(l) {
    True -> Ok(True)
    False ->
      Error(InvalidProperty(
        p.name,
        JsonArray(parser.list_to_indexed_dict(l), None),
      ))
  }
}
