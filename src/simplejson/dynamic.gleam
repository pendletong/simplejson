import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{Some}
import simplejson/internal/stringify
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

/// Converts provided JsonValue to dynamic data to allow for use
/// with decoders
pub fn to_dynamic(j: JsonValue) -> Dynamic {
  case j {
    JsonObject(d) -> {
      dict.fold(d, [], fn(l, k, v) {
        [#(dynamic.string(k), to_dynamic(v)), ..l]
      })
      |> dynamic.properties
    }
    JsonString(s) -> {
      dynamic.string(s)
    }
    JsonNumber(Some(i), _, _) -> {
      dynamic.int(i)
    }
    JsonNumber(_, Some(f), _) -> {
      dynamic.float(f)
    }
    JsonNumber(_, _, _) -> panic
    JsonArray(a) -> {
      stringify.dict_to_ordered_list(a)
      |> list.map(to_dynamic)
      |> list.reverse
      |> dynamic.array
    }
    JsonBool(bool:) -> dynamic.bool(bool)
    JsonNull -> dynamic.nil()
  }
}
