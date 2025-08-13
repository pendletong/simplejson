import gleam/bool
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import simplejson
import simplejson/internal/schema/schema
import simplejson/internal/stringify
import simplejson/jsonvalue.{JsonArray, JsonBool, JsonObject, JsonString}
import simplifile
import startest.{describe, it}
import startest/expect

const run_optional = False

pub fn main() {
  startest.run(startest.default_config())
}

pub fn suite_tests() {
  simplifile.get_files("./JSON-Schema-Test-Suite/tests/draft2020-12")
  |> expect.to_be_ok
  |> list.filter_map(fn(filename) {
    #(filename, string.contains(filename, "/optional/")) |> echo
    use <- bool.guard(
      when: string.contains(filename, "/optional/") && bool.negate(run_optional),
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
                                let res = schema.validate_json(schema, data)
                                case valid {
                                  True -> {
                                    expect.to_be_ok(res)
                                    Nil
                                  }
                                  False -> {
                                    expect.to_be_error(res)
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
