import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/error.{
  type InvalidEntry, FailedProperty, InvalidDataType, InvalidSchema,
}
import simplejson/internal/schema/properties/properties.{
  get_more_than_zero_property, get_number_property,
}
import simplejson/internal/schema/properties/propertyvalues.{
  type PropertyValue, NumberValue,
}
import simplejson/internal/schema/types.{type Number, Number}
import simplejson/jsonvalue.{type JsonValue, JsonNumber}

pub const int_properties = [
  #("multipleOf", get_more_than_zero_property, number_multiple_of),
  #("minimum", get_number_property, number_minimum),
  #("exclusiveMinimum", get_number_property, number_exclusiveminimum),
  #("maximum", get_number_property, number_maximum),
  #("exclusiveMaximum", get_number_property, number_exclusivemaximum),
]

fn number_minimum(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    NumberValue(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case i2 >= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 >=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }
          None, Some(f1) -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case int.to_float(i2) >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }

          _, _ -> Some(InvalidSchema(15))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusiveminimum(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    NumberValue(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case i2 > i1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 >. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }
          None, Some(f1) -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case int.to_float(i2) >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }

          _, _ -> Some(InvalidSchema(15))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_maximum(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    NumberValue(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case i2 <= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 <=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }
          None, Some(f1) -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case int.to_float(i2) <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }

          _, _ -> Some(InvalidSchema(15))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusivemaximum(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    NumberValue(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case i2 < i1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 <. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }
          None, Some(f1) -> {
            case v {
              JsonNumber(_, Some(i2), _, _) -> {
                case int.to_float(i2) <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              JsonNumber(_, _, Some(f2), _) -> {
                case f2 <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, v))
                }
              }
              _ -> Some(InvalidSchema(15))
            }
          }

          _, _ -> Some(InvalidSchema(15))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_multiple_of(
  value: PropertyValue,
) -> Result(fn(JsonValue) -> Option(InvalidEntry), InvalidEntry) {
  case value {
    NumberValue(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(_), None -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, v))
              Error(err) -> Some(err)
            }
          }
          None, Some(_) -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, v))
              Error(err) -> Some(err)
            }
          }

          _, _ -> Some(InvalidSchema(15))
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn is_multiple(num: JsonValue, of: Number) -> Result(Bool, InvalidEntry) {
  case num {
    JsonNumber(_, Some(i1), _, _) -> {
      case of {
        Number(Some(i2), None) -> {
          Ok(i1 % i2 == 0)
        }
        Number(None, Some(f2)) -> {
          let f1 = int.to_float(i1)
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        _ -> Error(InvalidSchema(17))
      }
    }
    JsonNumber(_, _, Some(f1), _) -> {
      case of {
        Number(Some(i2), None) -> {
          let f2 = int.to_float(i2)
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        Number(None, Some(f2)) -> {
          case float.modulo(f1, f2) {
            Ok(0.0) -> Ok(True)
            Ok(_) -> Ok(False)
            _ -> Error(InvalidSchema(18))
          }
        }
        _ -> Error(InvalidSchema(17))
      }
    }
    _ -> Error(InvalidSchema(19))
  }
}

pub fn validate_number(node: JsonValue) -> Result(Bool, List(InvalidEntry)) {
  case node {
    JsonNumber(_, _, _, _) -> Ok(True)
    _ -> Error([InvalidDataType(node)])
  }
}
