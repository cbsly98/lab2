ruleset wovyn_base {
    meta {
        name "Wovyn Base"
        description <<
        Ruleset for wovyn sensor
        >>
        author "Caleb Sly"
        use module com.twilio alias twilio
            with 
                username = ctx:rid_config{"username"}
                password = ctx:rid_config{"password"}
                fromNumber = ctx:rid_config{"fromNumber"}
        use module sensor_profile alias profile
        shares getThreshold
      }

    global {
        getThreshold = function() {
            profile:getProfileInformation(){"temperature_threshold"}
        }
        getPhoneNumber = function() {
            profile:getProfileInformation(){"phone_number"}
        }
    }

    rule process_heartbeat {
        select when wovyn heartbeat genericThing re#.+#
        pre {
            temperature = event:attrs{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"}.klog("temperature: ")
            timestamp = event:time.klog("timestamp: ")
        }
        send_directive("The temperature is: " + temperature.klog("directive-sent"))
        always {
            ent:curr_temp := temperature
            raise wovyn event "new_temperature_reading"
                attributes {"temperature" : temperature, "timestamp" : timestamp}
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
        }
        if temperature > getThreshold() then noop();
        fired {
            raise wovyn event "threshold_violation"
                attributes event:attrs
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        foreach profile:getSubscriptionInformation() setting(v, n)
        pre {
            tx_role = v{"Tx_role"}
            host = v{"Tx_host"}
            tx = v{"Tx"}
        }
        if tx_role == "community" then
            event:send(
                {   "eci": tx, 
                    "eid": "threshold-violation", 
                    "domain": "wovyn", "type": "threshold_violation",
                    "attrs": event:attrs
                }
            )
    }

    rule send_temperature {
        select when sensor report_requested
        pre {
            rcn = event:attrs{"rcn"}
            returnEci = event:attrs{"returnEci"}
        }
        event:send(
            {   "eci": returnEci, 
                "eid": "current-temperature", 
                "domain": "sensor_community", "type": "temperature_sent",
                "attrs": {
                    "rcn": rcn,
                    "temperature" : ent:curr_temp || "No readings yet",
                    "sensor_id" : profile:getSensorId()
                }
            }
        )
    }
}