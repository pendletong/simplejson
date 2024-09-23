import simplejson/internal/parser
import simplejson/jsonvalue.{type JsonValue}

pub fn parse(json: String) -> Result(JsonValue, Nil) {
  parser.parse(json)
}
