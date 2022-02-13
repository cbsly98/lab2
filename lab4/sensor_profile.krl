ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        description <<
        Ruleset for sensor profile
        >>
        author "Caleb Sly"
        provides getProfileInformation
        shares getProfileInformation
      }

    global {
        getProfileInformation = function() {
            {}.put("temperature_threshold", ent:temperature_threshold)
              .put("phone_number", ent:phone_number)
              .put("sensor_location", ent:sensor_location)
              .put("sensor_name", ent:sensor_name)
        }
    }

    rule init_vars {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        always {
            ent:temperature_threshold := 80
            ent:phone_number := "+13854502647"
            ent:sensor_location := "office"
            ent:sensor_name := "wovyn sensor 1"
        }
    }

    rule update_profile {
        select when sensor profile_updated
        pre {
            temperature_threshold = event:attrs{"temperature_threshold"}
            phone_number = event:attrs{"phone_number"}
            sensor_location = event:attrs{"sensor_location"}
            sensor_name = event:attrs{"sensor_name"}
        }
        always {
            ent:temperature_threshold := temperature_threshold || ent:temperature_threshold
            ent:phone_number := phone_number || ent:phone_number
            ent:sensor_location := sensor_location || ent:sensor_location
            ent:sensor_name := sensor_name || ent:sensor_name
        }
    }

}