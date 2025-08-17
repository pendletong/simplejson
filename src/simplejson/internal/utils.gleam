import gleam/option.{type Option, None, Some}
import simplejson/jsonvalue.{type JsonValue, JsonObject}

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
