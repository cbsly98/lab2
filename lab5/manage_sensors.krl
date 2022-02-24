ruleset manage_sensors {
    meta {
        name "Sensor Community"
        description <<
        Ruleset for sensor community (collection of sensors)
        >>
        author "Caleb Sly"
        use module io.picolabs.wrangler alias wrangler
        shares showChildren, sensors, temperatures
      }

    global {
        defaultThreshold = 90
        defaultPhoneNumber = "+13854502647"
        
        rulesetData = {
            "temperature_store" : {
                "rulesetURI" : "https://raw.githubusercontent.com/cbsly98/lab2/main/lab3/temperature_store.krl",
                "rid" : "temperature_store"
            },
            "twilio" : {
                "rulesetURI" : "https://raw.githubusercontent.com/cbsly98/lab1/main/com.twilio.krl",
                "rid" : "com.twilio"
            },
            "wovyn_base" : {
                "rulesetURI" : "https://raw.githubusercontent.com/cbsly98/lab2/lab4/wovyn_base.krl",
                "rid" : "wovyn_base"
            },
            "sensor_profile" : {
                "rulesetURI" : "https://raw.githubusercontent.com/cbsly98/lab2/lab4/lab4/sensor_profile.krl",
                "rid" : "sensor_profile"
            },
            "emitter" : {
                "rulesetURI" : "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl",
                "rid" : "io.picolabs.wovyn.emitter"
            }
        }

        nameFromID = function(id) {
            "Sensor " + id + " Pico"
        }

        showChildren = function() {
            wrangler:children()
        }

        sensors = function() {
            ent:sensors
        }

        installRuleset = defaction(eci, rulesetURI, rid, sensor_id) {
            event:send(
                { "eci": eci, 
                  "eid": "install-ruleset", 
                  "domain": "wrangler", "type": "install_ruleset_request",
                  "attrs": {
                    "absoluteURL": rulesetURI,
                    "rid": rid,
                    "config": {},
                    "sensor_id": sensor_id
                  }
                }
              )
        }

        temperatures = function() {
            ent:sensors.map(function(v, k) {
                wrangler:picoQuery(v{"eci"},"temperature_store","temperatures",{})
            })
        }
    }

    rule create_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
        }
        if exists then noop();
        notfired {
            raise wrangler event "new_child_request"
                attributes { "name": nameFromID(sensor_id), "backgroundColor": "#ff69b4", "sensor_id" : sensor_id }
        }
    }

    rule store_new_sensor {
        select when wrangler new_child_created
        pre {
            the_sensor = {"eci": event:attrs{"eci"}}
            sensor_id = event:attrs{"sensor_id"}
          }
          if sensor_id.klog("found sensor_id") then 
            every {
                installRuleset(the_sensor.get("eci"), rulesetData{["temperature_store", "rulesetURI"]}, rulesetData{["temperature_store", "rid"]}, sensor_id);
                installRuleset(the_sensor.get("eci"), rulesetData{["twilio", "rulesetURI"]}, rulesetData{["twilio", "rid"]}, sensor_id);
                installRuleset(the_sensor.get("eci"), rulesetData{["sensor_profile", "rulesetURI"]}, rulesetData{["sensor_profile", "rid"]}, sensor_id);
                installRuleset(the_sensor.get("eci"), rulesetData{["wovyn_base", "rulesetURI"]}, rulesetData{["wovyn_base", "rid"]}, sensor_id);
                installRuleset(the_sensor.get("eci"), rulesetData{["emitter", "rulesetURI"]}, rulesetData{["emitter", "rid"]}, sensor_id);
            }
          fired {
            ent:sensors{sensor_id} := the_sensor
            raise sensor event "rulesets_installed"
                attributes { "sensor": the_sensor, "sensor_id" : sensor_id }
          }
    }

    rule update_profile {
        select when sensor rulesets_installed
        pre {
            the_sensor = event:attrs{"sensor"}
            sensor_id = event:attrs{"sensor_id"}
        }
        if sensor_id then
            event:send(
                {   "eci": the_sensor.get("eci"), 
                    "eid": "update-profile", 
                    "domain": "sensor", "type": "profile_updated",
                    "attrs": {
                        "temperature_threshold": defaultThreshold,
                        "phone_number": defaultPhoneNumber,
                        "sensor_location": "noLocationSet",
                        "sensor_name": nameFromID(sensor_id)
                    }
                }
            )
    }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors >< sensor_id
            eci_to_delete = ent:sensors{[sensor_id,"eci"]}
        }
        if exists && eci_to_delete then noop();
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": eci_to_delete};
            clear ent:sensors{sensor_id}
        }
    }

}