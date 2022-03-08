ruleset manage_sensors {
    meta {
        name "Sensor Community"
        description <<
        Ruleset for sensor community (collection of sensors)
        >>
        author "Caleb Sly"
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        use module management_profile alias profile
        use module com.twilio alias twilio
            with 
                username = ctx:rid_config{"username"}
                password = ctx:rid_config{"password"}
                fromNumber = ctx:rid_config{"fromNumber"}
        shares showChildren, sensors, temperatures
      }

    global {
        defaultThreshold = 90
        defaultPhoneNumber = "+13854502647"

        getPhoneNumber = function() {
            profile:getProfileInformation(){"phone_number"}
        }
        
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
                "rulesetURI" : "file:///home/csly/Desktop/Winter2022/cs462/lab2/wovyn_base.krl",
                "rid" : "wovyn_base"
            },
            "sensor_profile" : {
                "rulesetURI" : "file:///home/csly/Desktop/Winter2022/cs462/lab2/lab4/sensor_profile.krl",
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
            ent:sensors.filter(function(v,k) {
                v{"Tx_role"} == "temperatureSensor"
            }).map(function(v, k) {
                wrangler:picoQuery(v{"subscriptionTx"},"temperature_store","temperatures",{}, v{"host"})
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
            ent:sensors{[sensor_id, "host"]} := "http://localhost:3000"
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

    rule accept_wellKnown {
        select when sensor identify
          sensor_id re#(.+)#
          wellKnown_eci re#(.+)#
          setting(sensor_id,wellKnown_eci)
        fired {
          ent:sensors{[sensor_id,"wellKnown_eci"]} := wellKnown_eci
          raise sensor event "identified"
            attributes { "sensor_id": sensor_id, "wellKnown_eci" : wellKnown_eci }
        }
    }

    rule introduce_sensor {
        select when sensor introduced
        pre {
            sensor_id = event:attrs{"sensor_id"}
            wellKnown_eci = event:attrs{"wellKnown_eci"}
            host = event:attrs{"host"}
        }
        always {
            ent:sensors{[sensor_id, "host"]} := host
            raise wrangler event "subscription"
                attributes { "wellKnown_Tx": wellKnown_eci, "Rx_role" : "community", "Tx_role" : "temperatureSensor", "name" : "sensorSubscription", "channel_type" : "sensorSubscription", "Tx_host" : host}
        }
    }

    rule create_subscription {
        select when sensor identified
        pre {
            sensor_id = event:attrs{"sensor_id"}
            wellKnown_eci = event:attrs{"wellKnown_eci"}
        }
        always {
            raise wrangler event "subscription"
                attributes { "wellKnown_Tx": wellKnown_eci, "Rx_role" : "community", "Tx_role" : "temperatureSensor", "name" : "sensorSubscription", "channel_type" : "sensorSubscription"}
        }
    }

    rule store_subscription {
        select when wrangler subscription_added
        pre {
            sensor_id = event:attrs{"sensor_id"}
        }
        always {
            ent:sensors{[sensor_id, "subscriptionTx"]} := event:attrs{"Tx"}
            ent:sensors{[sensor_id, "Tx_role"]} := event:attrs{"Rx_role"}
            ent:sensors{[sensor_id, "subscriptionId"]} := event:attrs{"Id"}
        }
    }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors >< sensor_id
            eci_to_delete = ent:sensors{[sensor_id,"eci"]}
            subscriptionId = ent:sensors{[sensor_id, "subscriptionId"]}
        }
        if exists && eci_to_delete then noop();
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": eci_to_delete};
            raise wrangler event "subscription_cancellation"
                attributes {"Id":subscriptionId}
            clear ent:sensors{sensor_id}
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            messageBody = "Temperature exceeded threshold at " + event:attrs{"timestamp"} + ". Current temperature is " + event:attrs{"temperature"}.klog("message: ")
        }
        twilio:sendMessage(getPhoneNumber(), messageBody)
    }

}