import gleam/bool
import gleam/result
import gleam/uri
import simplejson/jsonvalue.{
  type JsonPathError, type JsonValue, InvalidJsonPath, JsonArray, JsonObject,
  ParseError, PathNotFound,
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
            JsonArray(_, json_list) ->
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
        JsonObject(_, found_dict) ->
          case dict.get(found_dict, path_segment) {
            Ok(json_found_at_path) -> Ok(json_found_at_path)
            Error(_) -> Error(PathNotFound)
          }
        _ -> Error(PathNotFound)
      }
  }
}

pub fn jsonpointer(
  json: JsonValue,
  jsonpointer: String,
) -> Result(JsonValue, JsonPathError) {
  let #(split, fragment) = case string.split(jsonpointer, "/") {
    [] | [""] | ["#"] -> #([], False)
    ["#", ..rest] -> #(rest, True)
    [_, ..rest] -> #(rest, False)
  }
  use <- bool.guard(when: split == [], return: Ok(json))
  use current_json, path_segment <- list.try_fold(split, json)
  let path_segment =
    path_segment
    |> string.replace("~1", "/")
    |> string.replace("~0", "~")
    |> string.replace("\\\\", "\\")
    |> string.replace("\\\"", "\"")
  // decode %
  use path_segment <- result.try(case fragment {
    True ->
      uri.percent_decode(path_segment)
      |> result.replace_error(ParseError("Invalid path " <> path_segment))
    False -> Ok(path_segment)
  })
  case current_json {
    JsonObject(found_dict) ->
      case dict.get(found_dict, path_segment) {
        Ok(json_found_at_path) -> Ok(json_found_at_path)
        Error(_) -> Error(PathNotFound)
      }
    JsonArray(found_dict) -> {
      use i <- result.try(
        int.parse(path_segment)
        |> result.replace_error(ParseError(path_segment <> " is not a number")),
      )
      case dict.get(found_dict, i) {
        Ok(json_found_at_path) -> Ok(json_found_at_path)
        Error(_) -> Error(PathNotFound)
      }
    }
    _ -> Error(PathNotFound)
  }
}
