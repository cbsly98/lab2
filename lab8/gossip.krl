ruleset gossip {
    meta {
        name "Gossip"
        description <<
        Ruleset for gossip among temperature sensors
        >>
        author "Caleb Sly"
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        use module sensor_profile alias profile
        shares seen, getNumFromMessageID, messages, peers, genMessageID, getType, getRumorPeer, seenSets, getRandomMessage, getRumorMessage, getAddedRumorPeer, getNextMessage, getSeenPeer, getViolations, getInViolation
      }

    global {
        messages = function() {
            ent:messages
        }

        seen = function() {
            ent:seenSet
        }

        //only update this when we send a rumor or receive a seen set
        seenSets = function() {
            ent:seenSets
        }
        
        //return a peer to send a seen message to. This is a peer that has the most information
        getSeenPeer = function() {
            noSelf = ent:seenSets.filter(function(v,k) {
                k != wrangler:myself(){"id"}
            })
            diff = noSelf.map(function(v,k) {
                v.map(function(v1,k1) {
                    v1 + 1 - ent:seenSet{k1}
                }).values().reduce(function(a,b) {a + b})
            });
            missing = diff.values().sort("ciremun").head();
            diff.filter(function(v,k) {
                v == missing
            }).keys().head();
        }

        //return a peer to send a rumor message to
            //prioritize peers we don't have a seen set for, then largest missing information
        getRumorPeer = function() {
            unaddedPeers = ent:peers.filter(function(v,k) {
                ent:seenSets.keys().all(function(x) {k != x})
            })
            return (unaddedPeers.length() > 0) => unaddedPeers.keys().head() | getAddedRumorPeer();
            //go through map of seen Sets and reduce to the one that knows the least. check if a peer is not in set first
            //filter to find the first peer that doesn't have a message (or find the one missing the most)
            //could easily make the above a pair of a peer and a message with the random message
        }

        //return peer with the largest amount of missing information
        getAddedRumorPeer = function() {
            noSelf = ent:seenSets.filter(function(v,k) {
                k != wrangler:myself(){"id"}
            })
            diff = noSelf.map(function(v,k) {
                ent:seenSet.map(function(v1,k1) {
                    v1 + 1 - v{k1}
                }).values().reduce(function(a,b) {a + b})
            });
            missing = diff.values().sort("ciremun").head();
            diff.filter(function(v,k) {
                v == missing
            }).keys().head();
            //english description of the above code
            //comes from seen set. Need one that needs something. 
            //loop through each peer and check messages one at a time
            //could generate a new map that maps needed info to peer.
                //map to subtract what we know - what they know
                //collapse that map use values() to a peer and an array of values
                //reduce the values to one number
                //swap keys and values? or take values, sort, then filter on equal to given value
            //then sort keys and take the biggest peer. I like this.
        }

        getType = function() {
            (random:integer(1) == 0) => "rumor" | "seen";
        }

        peers = function() {
            ent:peers
        }

        getNumFromMessageID = function(MessageID) {
            arr = MessageID.split(re#:#);
            arr[1].as("Number")
        }

        genMessageID = function() {
            wrangler:myself(){"id"} + ":" + ent:nextNumber
        }

        sendMessage = defaction(peer, message, type) {
            event:send(
                { "eci": ent:peers{[peer, "channel"]}.klog(), 
                  "eid": "gossip-message", 
                  "domain": "gossip", "type": type.klog(),
                  "attrs": message.klog()
                }, host = ent:peers{[peer, "host"]}.klog()
              )
        }

        getRumorMessage = function(peer) {
            (ent:seenSets{peer}) => getNextMessage(peer) | getRandomMessage();
        }

        getRandomMessage = function() {
            ent:messages.values().head().filter(function(v,k) {
                getNumFromMessageID(k) == 0
            }).head().values().head();
        }

        //returns the next message the given peer needs
        getNextMessage = function (peer) {
            //I know ent:seenSets{peer} exists
            //Find first message they need
            //Only keep things in the map where seenSet has more than seenSets
            //grab one at random, then access message at picoid:number + 1

            selected = ent:seenSet.filter(function(v,k) {
                v > ent:seenSets{[peer, k]}
            }).head();
            pico = selected.keys().head();
            number = (ent:seenSets{[peer, pico]}) => ent:seenSets{[peer, pico]} + 1 | (ent:seenSets{[peer, pico]} == 0) => 1 | 0;
            messageID = pico + ":" + number
            ent:messages{[pico, messageID]}
        }

        getThreshold = function() {
            profile:getProfileInformation(){"temperature_threshold"}
        }

        getViolations = function() {
            ent:violations
        }

        getInViolation = function() {
            ent:inViolation
        }
    }

    rule init_vars {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:period := 8
            ent:go := true
            ent:nextNumber := 0
            ent:messages := {}
            ent:seenSet := {}
            ent:seenSets := {}
            ent:peers := {}
            schedule gossip event "heartbeat" repeat << */#{ent:period} * * * * * >>  attributes { } setting(id);
            ent:scheduleId := id;
            ent:violations := 0;
            ent:inViolation := false;
        }
    }

    rule clear_state {
        select when wovyn cleared_state
        always {
            ent:go := true
            ent:nextNumber := 0
            ent:messages := {}
            ent:seenSet := {}
            ent:seenSets := {}
            ent:peers := {}
        }
    }

    rule clear_messages {
        select when gossip cleared_messages
        always{
            ent:messages := {}
        }
    }

    rule process_heartbeat {
        select when gossip heartbeat
        pre {
            type = getType().klog();
            peer = (type == "rumor") => getRumorPeer() | getSeenPeer();
            message = (type == "rumor") => getRumorMessage(peer) | {}.put("peer", wrangler:myself(){"id"}).put("message", ent:seenSet);
        }
        if peer && ent:go then every {
            sendMessage(peer, message, type);
        }
        fired {
            ent:seenSets{[peer, message{"SensorID"}]} := getNumFromMessageID(message{"MessageID"}) if ((type == "rumor"));
        }
    }

    rule process_rumor {
        select when gossip rumor
        pre {
            MessageID = event:attrs{"MessageID"}
            SensorID = event:attrs{"SensorID"}
            Temperature = event:attrs{"Temperature"}
            Timestamp = event:attrs{"Timestamp"}
            SequenceNumber = getNumFromMessageID(MessageID);
            Payload = event:attrs{"Payload"}
        }
        if ent:go && MessageID then noop();
        fired {
            //additional logic for violation rumor. affect number of violations if you haven't seen the message yet.
            ent:violations := ent:violations + Payload if (Payload == 1 || Payload == -1) && ent:messages{[SensorID, MessageID]} == null
            //generic logic
            ent:messages{[SensorID, MessageID]} := event:attrs.delete("_headers") if ent:messages{[SensorID, MessageID]} == null
            ent:seenSet{SensorID} := ent:seenSet{SensorID} || SequenceNumber if SequenceNumber == 0
            ent:seenSet{SensorID} := SequenceNumber if SequenceNumber == ent:seenSet{SensorID} + 1
            ent:seenSets{wrangler:myself(){"id"}} := ent:seenSet
            
        }
    }

    rule process_seen {
        select when gossip seen
        pre {
            peer = event:attrs{"peer"}
            message = event:attrs{"message"}
        }
        if ent:go && peer then noop();
        fired {
            ent:seenSets{peer} := message
            raise gossip event "seen_processed"
                attributes {}.put(["peer"], peer)
        }
    }

    //sends messages if they are missing
    //This does not send the events in order
    rule send_missing_messages {
        select when gossip seen_processed
        foreach ent:messages setting (v, SensorID)
            foreach v setting (message, MessageID)
            pre {
                peer = event:attrs{"peer"}.klog()
                oldNum = ent:seenSets{[peer, SensorID]}
                newNum = getNumFromMessageID(MessageID)
            }
            if ent:go && ((oldNum < newNum) || (not oldNum)) then 
                sendMessage(peer, message, "rumor");
            fired {
                ent:seenSets{[peer, SensorID]} := ent:seenSets{[peer, SensorID]} || newNum if newNum == 0
                ent:seenSets{[peer, SensorID]} := newNum if newNum == oldNum + 1
            }
    }

    rule process_temperature {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        if ent:go then noop();
        fired {
            message = {}.put(["MessageID"], genMessageID())
                        .put(["SensorID"], wrangler:myself(){"id"})
                        .put(["Temperature"], temperature)
                        .put(["Timestamp"], timestamp)
            ent:nextNumber := ent:nextNumber + 1
            raise gossip event "rumor"
                attributes message
        }
    }

    rule pause_gossip {
        select when gossip paused
        always {
            ent:go := false
        }
    }

    rule start_gossip {
        select when gossip started
        always {
            ent:go := true
        }
    }

    rule update_period {
        select when gossip period_updated
        pre {
            period = event:attrs{"period"}
        }
        if period != ent:period then schedule:remove(ent:scheduleId);
        fired {
            ent:period := period
            schedule gossip event "heartbeat" repeat << */#{ent:period} * * * * * >>  attributes { } setting(id);
            ent:scheduleId := id;
        }
    }


    //subscriptions
    rule create_peer {
        select when gossip peer_requested
        pre {
            pico_id = event:attrs{"pico_id"}
            wellKnown_eci = event:attrs{"wellKnown_eci"}
            host = event:attrs{"host"} || "http://localhost:3000"
        }
        always {
            ent:peers{[pico_id, "host"]} := host || "http://localhost:3000"
            raise wrangler event "subscription"
                attributes { "wellKnown_Tx": wellKnown_eci, "Rx_role" : "node", "Tx_role" : "node", "name" : "gossipSubscription", "channel_type" : "gossipSubscription", "Tx_host" : host, "pico_id" : wrangler:myself(){"id"}}
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
          my_role = event:attrs{"Rx_role"}
          their_role = event:attrs{"Tx_role"}
          id = event:attrs{"Id"}
          host = event:attrs{"Tx_host"}
          pico_id = event:attrs{"pico_id"}.klog("passed in id: ")
        }
        if my_role=="node" && their_role=="node" then noop()
        fired {       
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs.put(["pico_id"], wrangler:myself(){"id"})
          ent:peers{[pico_id, "host"]} := host || "http://localhost:3000"
          ent:peers{[pico_id, "channel"]} := event:attrs{"Tx"}
        }
    }

    rule store_peer {
        select when wrangler subscription_added
        pre {
            pico_id = event:attrs{"pico_id"}
        }
        if pico_id && pico_id != wrangler:myself(){"id"} then noop();
        fired {
            ent:peers{[pico_id, "channel"]} := event:attrs{"Rx"}
        }
    }

    rule process_violations {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}
        }
        if temperature > getThreshold() then noop();
        fired {
            //raise message if transitioning to violation
            message = {}.put(["MessageID"], genMessageID())
                        .put(["SensorID"], wrangler:myself(){"id"})
                        .put(["Payload"], 1)
            raise gossip event "rumor" attributes message if not ent:inViolation
            ent:inViolation := not ent:inViolation if not ent:inViolation
        } else {
            //raise message if transitioning to normal
            message = {}.put(["MessageID"], genMessageID())
                        .put(["SensorID"], wrangler:myself(){"id"})
                        .put(["Payload"], -1)
            raise gossip event "rumor" attributes message if ent:inViolation
            ent:inViolation := not ent:inViolation if ent:inViolation
        }
    }

}