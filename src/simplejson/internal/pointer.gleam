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
  use current_json, path_segment <- list.try_fold(
    string.split(jsonpath, "."),
    json,
  )
  case path_segment {
    // Path segment is empty (ignore successive "." in the jsonpath)
    "" -> Ok(current_json)
    // Path segment is an array index, we should expect the given json to be an array
    "#" <> array_index ->
      case int.parse(array_index) {
        Ok(index) ->
          case current_json {
            JsonArray(json_list) ->
              case dict.get(json_list, index) {
                Ok(found_json) -> Ok(found_json)
                Error(_) -> Error(PathNotFound)
              }
            _ -> Error(PathNotFound)
          }
        Error(_) -> Error(InvalidJsonPath)
      }
    // Path segment is a string, we should expect the given json to be an object
    _ ->
      case current_json {
        JsonObject(found_dict) ->
          case dict.get(found_dict, path_segment) {
            Ok(json_found_at_path) -> Ok(json_found_at_path)
            Error(_) -> Error(PathNotFound)
          }
        _ -> Error(PathNotFound)
      }
  }
}
