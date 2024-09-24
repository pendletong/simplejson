import glychee/benchmark
import glychee/configuration
import simplejson

@target(erlang)
pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  small_benchmark()
}

@target(erlang)
pub fn small_benchmark() {
  benchmark.run(
    [
      benchmark.Function("simplejson", fn(data) {
        fn() { simplejson.parse(data) }
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
