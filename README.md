# simplejson

[![Package Version](https://img.shields.io/hexpm/v/simplejson)](https://hex.pm/packages/simplejson)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/simplejson/)

Basic JSON library for Gleam. To be used for simple conversion from string to a basic JSON structure and to then output that as a string again.

## Installation

```sh
gleam add simplejson@1
```
```gleam
import simplejson

pub fn main() {
  let json = simplejson.parse("[1,2,3]")

  echo simplejson.stringify(json)
}
```

Further documentation can be found at <https://hexdocs.pm/simplejson>.

## Targets

As this uses only stdlib and regexp this should fully support both JavaScript and Erlang
