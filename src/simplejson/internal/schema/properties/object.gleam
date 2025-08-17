import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/error.{
  type InvalidEntry, FailedProperty, InvalidDataType, InvalidSchema,
}
import simplejson/internal/schema/properties/properties

import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, IntValue, ListValue,
}

import simplejson/jsonvalue.{type JsonValue, JsonObject}

pub const object_properties: List(
  #(
    String,
    fn(String, Dict(String, JsonValue)) ->
      Result(Option(PropertyValue), InvalidEntry),
    fn(PropertyValue) ->
      Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry),
  ),
) = [
  #("minProperties", properties.get_positive_int_property, min_props),
  #("maxProperties", properties.get_positive_int_property, max_props),
  #("required", properties.get_unique_string_list_property, required),
  // #("properties", properties.get_object_property, properties)
]

// fn properties(value: PropertyValue) {
//   case value {
//     ObjectValue(_, props) -> {
//       Ok(fn(v) {
//         case v {
//           JsonObject(d, _) -> {
//             dict.to_list(props)
//             |> list.try_each(fn(i) {
//               let #(key, validation) = i
//               case dict.get(d, key) {
//                 Error(_) -> Ok(True)
//                 Ok(v) -> {
//                   validate_node(v, validation)
//                 }
//               }
//             })
//             |> result.replace(True)
//           }
//           _ -> Some(InvalidDataType(v))
//         }

//     })}
//     _ -> Error(InvalidSchema(19))
//   }
// }

fn required(value: PropertyValue) {
  case value {
    ListValue(_, l) -> {
      Ok(fn(v) {
        case v {
          JsonObject(o, _) -> {
            let keys = dict.keys(o)
            case
              list.find(l, fn(k) {
                let assert propertyvalues.StringValue(_, k) = k
                case list.contains(keys, k) {
                  False -> True
                  True -> False
                }
              })
            {
              Error(_) -> None
              Ok(_) -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidDataType(v))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn min_props(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value |> echo as "minprops" {
    IntValue(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonObject(l, _) -> {
            case dict.size(l) >= i {
              True -> None
              False -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidDataType(v))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn max_props(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    IntValue(_, i) -> {
      Ok(fn(v) {
        case v {
          JsonObject(l, _) -> {
            case dict.size(l) <= i {
              True -> None
              False -> Some(FailedProperty(value, v))
            }
          }
          _ -> Some(InvalidSchema(35))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}
