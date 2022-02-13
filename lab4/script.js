const queryString = window.location.search;
const urlParams = new URLSearchParams(queryString);
const eci = urlParams.get("eci");
let current = false;

function onClick(e) {
    if (e != null) {
        e.preventDefault();
    }

    let s = document.getElementById('selector');
    let type = s.options[s.selectedIndex].value;

    // setup URL
    let url = "";
    current = false;
    if (type == "current") {
        url = "http://localhost:3000/c/" + eci + "/query/temperature_store/temperatures";
        current = true;
    } else if (type == "recent") {
        url = "http://localhost:3000/c/" + eci + "/query/temperature_store/temperatures";
    } else {
        url = "http://localhost:3000/c/" + eci + "/query/temperature_store/threshold_violations";
    }

    // call Pico
    fetch(url)
        .then(function (response) {
            // make sure the request was successful
            if (response.status != 200) {
                return {
                    text: "Error calling the pico: " + response.statusText
                }
            }
            return response.json();
            
        }).then(function (json) {
            // update DOM with response
            updateResult(json);
        });
}

function updateResult(data) {
    let numResults = 0;
    var tempList = document.getElementById('temperatures');
    tempList.innerHTML = "";
    var keys = [];
    for (var key in data) {
        keys.push(key);
    }
    for (var i = keys.length - 1; i >= 0; i--) {
        tempList.innerHTML += "<li>TimeStamp: " + keys[i] + " Temperature: " + data[keys[i]] + "</li>";
        //only display most recent temperature if looking for current temperature
        if (current) {
            return;
        }
        //only display the most recent 10 temperatures
        if (numResults >= 10) {
            break;
        }
        ++numResults;
    }
    if (numResults == 0) {
        tempList.innerHTML = "There is no data associated with your selection."
    }
}

//basic polling to keep the data "live". Repolls every 5 seconds.
function refresh() {
    onClick(null);
    setTimeout(refresh, 5000);
}

setTimeout(refresh, 5000);

function onClickReadings(e) {
    if (e != null) {
        e.preventDefault();
    }
    let s = document.getElementById('content');
    s.innerHTML = "<h1>Wovyn Sensor Readings</h1> \
    <p></p> \
    <select id=\"selector\"> \
      <option value=\"current\">Current</option> \
      <option value=\"recent\">Recent</option> \
      <option value=\"violations\">Violations</option> \
    </select> \
  </br> \
    <button id=\"go\" class=\"pure-button pure-button-primary\">Go!</button> \
    <ul id=\"temperatures\"></ul>"
    document.getElementById('go').addEventListener('click', onClick);
}

function onClickProfile(e) {
    if (e != null) {
        // e.preventDefault();
    }
    let s = document.getElementById('content');
    let updateProfileUrl = "http://localhost:3000/c/" + eci + "/event-wait/sensor/profile_updated"
    s.innerHTML = "<form target=\"_blank\" action=\"" + updateProfileUrl + "\" method=\"post\" id=\"profile\"> \
	<h1>Sensor Profile</h1> \
	<div class=\"field\"> \
		<label for=\"sensor_name\">Name:</label> \
		<input type=\"text\" id=\"sensor_name\" name=\"sensor_name\" placeholder=\"Enter Sensor Name\" /> \
		<small></small> \
	</div> \
	<div class=\"field\"> \
		<label for=\"phone_number\">Phone:</label> \
		<input type=\"text\" id=\"phone_number\" name=\"phone_number\" placeholder=\"+1234567890\" /> \
		<small></small> \
	</div> \
  <div class=\"field\"> \
		<label for=\"temperature_threshold\">Temperature Threshold:</label> \
		<input type=\"number\" id=\"temperature_threshold\" name=\"temperature_threshold\" placeholder=\"Enter Temperature Threshold\" /> \
		<small></small> \
	</div> \
  <div class=\"field\"> \
		<label for=\"sensor_location\">Sensor Location:</label> \
		<input type=\"text\" id=\"sensor_location\" name=\"sensor_location\" placeholder=\"Enter Sensor Location\" /> \
		<small></small> \
	</div> \
	<button id=\"submit\" type=\"submit\">Update</button> \
</form>"
    let url = "http://localhost:3000/c/" + eci + "/query/sensor_profile/getProfileInformation";

    fetch(url)
    .then(function (response) {
        // make sure the request was successful
        if (response.status != 200) {
            return {
                text: "Error calling the pico: " + response.statusText
            }
        }
        return response.json();
        
    }).then(function (json) {
        // update DOM with response
        updateProfileResult(json);
    });
}

function updateProfileResult(data) {
    let temperature_threshold = data["temperature_threshold"];
    document.getElementById("temperature_threshold").value = temperature_threshold;
    let phone_number = data["phone_number"];
    document.getElementById("phone_number").value = phone_number;
    let sensor_location = data["sensor_location"];
    document.getElementById("sensor_location").value = sensor_location;
    let sensor_name = data["sensor_name"];
    document.getElementById("sensor_name").value = sensor_name;
}

document.getElementById('go').addEventListener('click', onClick);
document.getElementById('readings').addEventListener('click', onClickReadings);
document.getElementById('profile').addEventListener('click', onClickProfile);
//TODO: add listener for the selector. When that changes, run the query.
