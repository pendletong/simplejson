import simplejson/internal/jsonpath
import simplejson/internal/parser
import simplejson/internal/query

pub fn main2() {
  let assert Ok(json) =
    parser.parse(
      "{
        \"a\":{\"c\":1,
        \"b\":2}
      }",
    )
  let assert Ok(result) = parser.parse("[1,2]") |> echo
  let assert Ok(path) = jsonpath.parse_path("$.a[?\"a\"==\"a\"]") |> echo

  { query.query(json, path, json) == result } |> echo
}

pub fn main() {
  let assert Ok(json) =
    parser.parse(
      "[
        \" \",
        \"\\r\",
        \"\\n\",
        true,
        [],
        {}
      ]",
    )
  let assert Ok(result) =
    parser.parse(
      "[
        \"_\"
      ]",
    )
  let assert Ok(path) = jsonpath.parse_path("$[?match(@, '.')]") |> echo

  { query.query(json, path, json) |> echo == result } |> echo
}

pub fn main4() {
  let assert Ok(json) =
    parser.parse(
      "{
        \"c\": \"cd\",
        \"values\": [
          {
            \"a\": \"ab\"
          },
          {
            \"a\": \"d\"
          }
        ]
      }",
    )
  let assert Ok(result) =
    parser.parse(
      "[
        {
          \"a\": true,
          \"d\": \"e\"
        }
      ]",
    )
  let assert Ok(path) =
    jsonpath.parse_path("$.values[?length(@.a)==length(value($..c))]") |> echo

  { query.query(json, path, json) == result } |> echo
}
