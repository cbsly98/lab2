ruleset sensor_profile {
    meta {
        name "Sensor Profile"
        description <<
        Ruleset for sensor profile
        >>
        author "Caleb Sly"
        provides getProfileInformation, getSubscriptionInformation
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares getProfileInformation, getSubscriptionInformation
      }

    global {
        getProfileInformation = function() {
            {}.put("temperature_threshold", ent:temperature_threshold)
              .put("phone_number", ent:phone_number)
              .put("sensor_location", ent:sensor_location)
              .put("sensor_name", ent:sensor_name)
        }

        getSubscriptionInformation = function() {
            ent:subscriptions
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

    rule send_wellKnown {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        pre {
            sensor_id = event:attr("sensor_id")
            parent_eci = wrangler:parent_eci()
            wellKnown_eci = subs:wellKnown_Rx(){"id"}
          }
          event:send({"eci":parent_eci,
            "domain": "sensor", "type": "identify",
            "attrs": {
              "sensor_id": sensor_id,
              "wellKnown_eci": wellKnown_eci
            }
          })
          always {
            ent:sensor_id := sensor_id
          }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
          my_role = event:attr("Rx_role")
          their_role = event:attr("Tx_role")
          id = event:attr("Id")
          host = event:attr("Tx_host")
        }
        if my_role=="temperatureSensor" && their_role=="community" then noop()
        fired {       
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs.put(["sensor_id"], ent:sensor_id)
          ent:subscriptions{[id, "Rx_role"]} := my_role
          ent:subscriptions{[id, "Tx_role"]} := their_role
          ent:subscriptions{[id, "Tx_host"]} := host || "http://localhost:3000"
          ent:subscriptions{[id, "Tx"]} := event:attr("Tx")

          ent:subscriptionTx := event:attr("Tx")
        } else {
          raise wrangler event "inbound_rejection"
            attributes event:attrs
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