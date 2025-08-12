# simplejson

[![Package Version](https://img.shields.io/hexpm/v/simplejson)](https://hex.pm/packages/simplejson)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/simplejson/)

JSON library for Gleam with JsonPath querying (https://www.rfc-editor.org/rfc/rfc9535).

## Installation

```sh
gleam add simplejson@1
```
```gleam
import simplejson

pub fn main() {
  let assert Ok(json) = simplejson.parse("[1,2,3]")

  echo simplejson.to_string(json) // -> [1,2,3]

  let assert Ok(path) = simplejson.to_path("$[1]")

  echo simplejson.query(json, path) // -> JsonArray(dict.from_list([#(0, JsonNumber(Some(2), None, Some("2")))]))
}
```

Further documentation can be found at <https://hexdocs.pm/simplejson>.

## Targets

As this uses only stdlib and regexp this should fully support both JavaScript and Erlang
