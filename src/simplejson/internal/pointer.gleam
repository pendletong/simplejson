import simplejson/jsonvalue.{
  type JsonPathError, type JsonValue, InvalidJsonPath, JsonArray, JsonObject,
  PathNotFound,
}

import gleam/dict
import gleam/int
import gleam/list
import gleam/string

pub fn jsonpath(
  json: JsonValue,
  jsonpath: String,
) -> Result(JsonValue, JsonPathError) {
  use current_json_result, path_segment <- list.fold_until(
    string.split(jsonpath, "."),
    Ok(json),
  )
  let assert Ok(current_json) = current_json_result
  case path_segment {
    // Path segment is empty (ignore successive "." in the jsonpath)
    "" -> list.Continue(Ok(current_json))
    // Path segment is an array index, we should expect the given json to be an array
    "#" <> array_index ->
      case int.parse(array_index) {
        Ok(index) ->
          case current_json {
            JsonArray(_, json_list) ->
              case dict.get(json_list, index) {
                Ok(found_json) -> list.Continue(Ok(found_json))
                Error(_) -> list.Stop(Error(PathNotFound))
              }
            _ -> list.Stop(Error(PathNotFound))
          }
        Error(_) -> list.Stop(Error(InvalidJsonPath))
      }
    // Path segment is a string, we should expect the given json to be an object
    _ ->
      case current_json {
        JsonObject(_, found_dict) ->
          case dict.get(found_dict, path_segment) {
            Ok(json_found_at_path) -> list.Continue(Ok(json_found_at_path))
            Error(_) -> list.Stop(Error(PathNotFound))
          }
        _ -> list.Stop(Error(PathNotFound))
      }
  }
}
