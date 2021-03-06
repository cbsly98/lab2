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
      }

    global {
        temperature_threshold = 80
        phone_number = "+13854502647"
    }

    rule process_heartbeat {
        select when wovyn heartbeat genericThing re#.+#
        pre {
            temperature = event:attrs{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"}.klog("temperature: ")
            timestamp = event:time.klog("timestamp: ")
        }
        send_directive("The temperature is: " + temperature.klog("directive-sent"))
        always {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature" : temperature, "timestamp" : timestamp}
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
        }
        if temperature > temperature_threshold then noop();
        fired {
            raise wovyn event "threshold_violation"
                attributes event:attrs
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            messageBody = "Temperature exceeded threshold at " + event:attrs{"timestamp"} + ". Current temperature is " + event:attrs{"temperature"}.klog("message: ")
        }
        twilio:sendMessage(phone_number, messageBody)
    }
}