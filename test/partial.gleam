import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import simplejson
import simplejson/internal/schema2/schema2
import simplejson/internal/schema2/validator2
import simplejson/internal/stringify
import simplejson/jsonvalue.{JsonArray, JsonBool, JsonObject, JsonString}
import simplifile
import startest.{describe, it}
import startest/expect

const run_optional = False

const files = [
  "type.json",
  "boolean_schema.json",
  // "const.json",
// "enum.json",
// "minProperties.json",
// "maxProperties.json",
// "items.json",
]

pub fn main() {
  startest.run(startest.default_config())
}

pub fn suite_tests() {
  simplifile.get_files("./JSON-Schema-Test-Suite/tests/draft2020-12")
  |> expect.to_be_ok
  |> list.filter_map(fn(filename) {
    use <- bool.guard(
      when: string.contains(filename, "/optional/") && bool.negate(run_optional),
      return: Error(Nil),
    )
    use <- bool.guard(
      when: list.fold_until(files, True, fn(_, f) {
        case string.contains(filename, f) {
          True -> list.Stop(False)
          False -> list.Continue(True)
        }
      }),
      return: Error(Nil),
    )

    case
      simplifile.read(filename)
      |> expect.to_be_ok
      |> simplejson.parse
      |> expect.to_be_ok
    {
      JsonArray(items, _) -> {
        Ok(describe(
          filename,
          list.try_map(stringify.dict_to_ordered_list(items), fn(t) {
            case t {
              JsonObject(entries, _) -> {
                use description <- result.try(dict.get(entries, "description"))
                use schema <- result.try(dict.get(entries, "schema"))
                use tests <- result.try(dict.get(entries, "tests"))

                case tests {
                  JsonArray(t, _) -> {
                    list.try_map(
                      stringify.dict_to_ordered_list(t),
                      fn(test_json) {
                        case test_json {
                          JsonObject(d, _) -> {
                            use data <- result.try(dict.get(d, "data"))
                            use valid <- result.try(dict.get(d, "valid"))
                            use desc <- result.try(dict.get(d, "description"))
                            let assert JsonString(desc, _) = desc
                            let assert JsonBool(valid, _) = valid
                            let assert JsonString(description, _) = description
                            Ok(
                              it(description <> " -> " <> desc, fn() {
                                let schema =
                                  schema2.get_validator_from_json(schema)
                                  |> expect.to_be_ok
                                let validated =
                                  validator2.validate(data, schema)
                                case valid {
                                  True -> {
                                    expect.to_be_true(validated.0)
                                    Nil
                                  }
                                  False -> {
                                    expect.to_be_some(validated.1)
                                    Nil
                                  }
                                }
                              }),
                            )
                          }
                          _ -> Error(Nil)
                        }
                      },
                    )
                  }
                  _ -> Error(Nil)
                }
              }
              _ -> Error(Nil)
            }
          })
            |> expect.to_be_ok
            |> list.flatten,
        ))
      }
      _ -> Error(Nil)
    }
  })
  |> describe("Schema testfiles", _)
}
