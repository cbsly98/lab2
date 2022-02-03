ruleset temperature_store {
    meta {
        name "Temperature Store"
        description <<
        Ruleset for storing temperatures
        >>
        author "Caleb Sly"
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
      }

    global {
        temperatures = function() {
            ent:temps
        }

        threshold_violations = function() {
            ent:violation_temps
        }

        inrange_temperatures = function() {
            ent:temps.filter(function(v, k) {
                ent:violation_temps.keys().index(k) == -1
            })
        }
    }

    rule init_vars {
        select when wrangler ruleset_installed where event:attr("rids") >< meta:rid
        always {
            ent:temps := {}
            ent:violation_temps := {}
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        always {
            ent:temps{timestamp} := temperature
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        always {
            ent:violation_temps{timestamp} := temperature
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always {
            ent:temps := {}
            ent:violation_temps := {}
        }
    }
}