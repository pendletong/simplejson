import gleam/dict
import gleam/function
import gleam/list.{Continue, Stop}
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema2/types.{
  type Combination, type Context, type Property, type SchemaError, Context,
  InvalidProperty, MultipleValidation,
}
import simplejson/jsonvalue.{
  type JsonValue, JsonArray, JsonBool, JsonNull, JsonNumber, JsonObject,
  JsonString,
}

pub fn merge_context(context1: Context, context2: Context) -> Context {
  Context(
    ..context1,
    current_validator: None,
    schemas: dict.merge(context2.schemas, context1.schemas),
  )
}

pub fn construct_new_context(
  context: Context,
  contexts: List(Option(List(Context))),
) -> Context {
  list.fold(
    contexts
      |> option.values
      |> list.flatten,
    context,
    fn(context, new_context) { merge_context(context, new_context) },
  )
}

pub fn revert_current_node(
  context: Result(Context, x),
  original_json: JsonValue,
) -> Result(Context, x) {
  case context {
    Ok(context) -> Ok(Context(..context, current_node: original_json))
    Error(e) -> Error(e)
  }
}

pub fn unwrap_context_list(contexts: List(Context)) {
  list.map(contexts, fn(context) { context.current_validator })
  |> option.values
}

pub fn unwrap_to_multiple(
  contexts: Option(List(Context)),
  combination: Combination,
) -> Option(types.ValidationNode) {
  option.map(contexts, fn(contexts) {
    unwrap_context_list(contexts)
    |> MultipleValidation(combination, function.identity)
  })
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
  v: JsonValue,
  _c: Context,
  p: Property,
) -> Result(Bool, SchemaError) {
  let assert JsonArray(l, _) = v
  case is_unique(dict.values(l)) {
    True -> Ok(True)
    False -> Error(InvalidProperty(p.name, v))
  }
}
