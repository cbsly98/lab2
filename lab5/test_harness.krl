ruleset test_harness {
    meta {
        name "Sensor Community Test Harness"
        description <<
        Ruleset for testing sensor community
        >>
        author "Caleb Sly"
        use module io.picolabs.wrangler alias wrangler
        shares temperatures, sensor_profile
      }

      //these functions allow access to child picos
      global {
          temperatures = function(eci) {
            wrangler:picoQuery(eci,"temperature_store","temperatures",{})
          }

          sensor_profile = function(eci) {
            wrangler:picoQuery(eci,"sensor_profile","getProfileInformation",{})
          }
      }
}