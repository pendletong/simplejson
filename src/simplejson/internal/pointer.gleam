import gleam/bool
import gleam/result
import gleam/uri
import simplejson/jsonvalue.{
  type JsonPathError, type JsonPointerError, type JsonValue, InvalidJsonPath,
  InvalidPointer, JsonArray, JsonObject, ParseError, PathNotFound,
  PointerParseError, PointerPathNotFound,
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
            JsonArray(json_list, _) ->
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
        JsonObject(found_dict, _) ->
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
) -> Result(JsonValue, JsonPointerError) {
  use #(split, fragment) <- result.try(case string.split(jsonpointer, "/") {
    [] | [""] | ["#"] -> Ok(#([], False))
    ["#", ..rest] -> Ok(#(rest, True))
    ["", ..rest] -> Ok(#(rest, False))
    _ -> Error(InvalidPointer)
  })
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
      |> result.replace_error(PointerParseError("Invalid path " <> path_segment))
    False -> Ok(path_segment)
  })
  case current_json {
    JsonObject(found_dict, _) ->
      case dict.get(found_dict, path_segment) {
        Ok(json_found_at_path) -> Ok(json_found_at_path)
        Error(_) -> Error(PointerPathNotFound)
      }
    JsonArray(found_dict, _) -> {
      use i <- result.try(
        int.parse(path_segment)
        |> result.replace_error(PointerParseError(
          path_segment <> " is not a number",
        )),
      )
      case dict.get(found_dict, i) {
        Ok(json_found_at_path) -> Ok(json_found_at_path)
        Error(_) -> Error(PointerPathNotFound)
      }
    }
    _ -> Error(PointerPathNotFound)
  }
}
