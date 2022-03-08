ruleset management_profile {
    meta {
        name "Sensor Community Profile"
        description <<
        Ruleset for sensor community profile
        >>
        author "Caleb Sly"
        provides getProfileInformation
        shares getProfileInformation
      }

    global {
        getProfileInformation = function() {
            {}.put("phone_number", ent:phone_number)
        }
    }

    rule init_vars {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        always {
            ent:phone_number := "+13854502647"
        }
    }

    rule update_profile {
        select when sensor_community profile_updated
        pre {
            phone_number = event:attrs{"phone_number"}
        }
        always {
            ent:phone_number := phone_number || ent:phone_number
        }
    }

}