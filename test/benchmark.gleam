import gleam/dynamic/decode
import gleam/json
import glychee/benchmark
import glychee/configuration
import simplejson
import simplejson_test

type Props {
  Props
}

type Geometry {
  Geometry(t: String, coordinates: List(List(Float)))
}

type Feature {
  Feature(t: String, properties: Props, geometry: Geometry)
}

type BMData {
  BMData(t: String, features: List(Feature))
}

@target(erlang)
pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  small_benchmark()
  array_benchmark()

  stringify_benchmark()
}

@target(erlang)
pub fn array_benchmark() {
  benchmark.run(
    [
      benchmark.Function("array_benchmark", fn(data) {
        fn() {
          let _ = simplejson.parse(data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data(
        "array",
        "{\"list\":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]}",
      ),
    ],
  )
}

@target(erlang)
pub fn stringify_benchmark() {
  let assert Ok(array) =
    simplejson.parse("[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]")
  let assert Ok(obj) =
    simplejson.parse(
      "{\"a\":1,\"b\":2,\"c\":3,\"d\":4,\"e\":5,\"f\":6,\"g\":7,\"h\":8,\"i\":9,\"j\":10}",
    )
  let assert Ok(mixed) = simplejson_test.read_file("./test/benchmark.json")
  let assert Ok(mixed) = simplejson.parse(mixed)

  benchmark.run(
    [
      benchmark.Function("stringify_array", fn(data) {
        fn() {
          let _ = simplejson.to_string(data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data("array", array),
      benchmark.Data("obj", obj),
      benchmark.Data("mixed", mixed),
    ],
  )
}

@target(erlang)
pub fn small_benchmark() {
  benchmark.run(
    [
      benchmark.Function("simplejson", fn(data) {
        fn() {
          let _ = simplejson.parse(data)
          Nil
        }
      }),
      benchmark.Function("gleam_json", fn(data) {
        fn() {
          let props_decoder = {
            decode.success(Props)
          }

          let geometry_decoder = {
            use gt <- decode.field("type", decode.string)
            use coords <- decode.field(
              "coordinates",
              decode.list(decode.list(decode.float)),
            )

            decode.success(Geometry(gt, coords))
          }
          let feature_decoder = {
            use ft <- decode.field("type", decode.string)
            use props <- decode.optional_field(
              "properties",
              Props,
              props_decoder,
            )
            use geometry <- decode.field("geometry", geometry_decoder)

            decode.success(Feature(ft, props, geometry))
          }
          let decoder = {
            use jt <- decode.field("type", decode.string)
            use features <- decode.field(
              "features",
              decode.list(feature_decoder),
            )
            decode.success(BMData(jt, features))
          }
          let _ = json.parse(from: data, using: decoder)
          Nil
        }
      }),
    ],
    [
      benchmark.Data(
        "simple json",
        "{  \"type\": \"FeatureCollection\",  \"features\": [    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Point\",        \"coordinates\": [4.483605784808901, 51.907188449679325]      }    },    {      \"type\": \"Feature\",      \"properties\": {},      \"geometry\": {        \"type\": \"Polygon\",        \"coordinates\": [          [            [3.974369110811523 , 51.907355547778565],            [4.173944459020191 , 51.86237166892457 ],            [4.3808076710679416, 51.848867725914914],            [4.579822414365026 , 51.874487141880024],            [4.534413416598767 , 51.9495302480326  ],            [4.365110733567974 , 51.92360787140825 ],            [4.179550508127079 , 51.97336560819281 ],            [4.018096293847009 , 52.00236546429852 ],            [3.9424146309028174, 51.97681895676649 ],            [3.974369110811523 , 51.907355547778565]          ]        ]      }}]}",
      ),
    ],
  )
}
