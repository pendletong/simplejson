import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import simplejson/internal/schema/properties/properties.{get_number_property}
import simplejson/internal/schema/types.{
  type InvalidEntry, type Number, type ValidationProperty, FailedProperty,
  InvalidSchema, Number, NumberProperty,
}
import simplejson/jsonvalue.{type JsonValue}

pub const int_properties = [
  #("multipleOf", get_number_property, number_multiple_of),
  #("minimum", get_number_property, number_minimum),
  #("exclusiveMinimum", get_number_property, number_exclusiveminimum),
  #("maximum", get_number_property, number_maximum),
  #("exclusiveMaximum", get_number_property, number_exclusivemaximum),
]

fn number_minimum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 >= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusiveminimum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 > i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 >. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_maximum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 <= i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <=. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <=. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_exclusivemaximum(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(i1), None -> {
            case v {
              Number(Some(i2), _) -> {
                case i2 < i1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <. int.to_float(i1) {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }
          None, Some(f1) -> {
            case v {
              Number(Some(i2), _) -> {
                case int.to_float(i2) <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              Number(_, Some(f2)) -> {
                case f2 <. f1 {
                  True -> None
                  False -> Some(FailedProperty(value, _))
                }
              }
              _ -> Some(fn(_) { InvalidSchema(15) })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn number_multiple_of(
  value: ValidationProperty,
) -> Result(fn(Number) -> Option(fn(JsonValue) -> InvalidEntry), InvalidEntry) {
  case value {
    NumberProperty(_, i, f) -> {
      Ok(fn(v) {
        case i, f {
          Some(_), None -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, _))
              Error(err) -> Some(fn(_) { err })
            }
          }
          None, Some(_) -> {
            case is_multiple(v, Number(i, f)) {
              Ok(True) -> None
              Ok(False) -> Some(FailedProperty(value, _))
              Error(err) -> Some(fn(_) { err })
            }
          }

          _, _ -> Some(fn(_) { InvalidSchema(15) })
        }
      })
    }
    _ -> Error(InvalidSchema(14))
  }
}

fn is_multiple(num: Number, of: Number) -> Result(Bool, InvalidEntry) {
  case num {
    Number(Some(i1), None) -> {
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
    Number(None, Some(f1)) -> {
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
