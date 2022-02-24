const queryString = window.location.search;
const urlParams = new URLSearchParams(queryString);
const eci = urlParams.get("eci");
const childrenToCreate = 10;
let children = {};


function onClick(e) {
    document.getElementById('content').innerHTML = "test started</br>";

    //delete any residue children (start with blank slate)
    deleteChildUrl = "http://localhost:3000/c/" + eci + "/event-wait/sensor/unneeded_sensor";
    for (let i = 0; i < childrenToCreate + 1; i++) {
        post(deleteChildUrl, {"sensor_id" : i}, i);
    }
    document.getElementById('content').innerHTML += "children deleted</br>";

    //create children
    createChildUrl = "http://localhost:3000/c/" + eci + "/event-wait/sensor/new_sensor";
    for (let i = 1; i < childrenToCreate + 1; i++) {
        post(createChildUrl, {"sensor_id" : i}, i + childrenToCreate);
    }
    document.getElementById('content').innerHTML += "children created</br>";

    //ensure children were created
    sensorsUrl = "http://localhost:3000/c/" + eci + "/query/manage_sensors/sensors";
    fetch(sensorsUrl)
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
            checkCount(json, childrenToCreate);
            //delete single child
            post(deleteChildUrl, {"sensor_id" : 3}, 100);
            document.getElementById('content').innerHTML += "deleting child</br>";

            //ensure child was deleted
            fetch(sensorsUrl)
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
                checkCount(json, childrenToCreate - 1);
                });
            
            //verify temperatures responding correctly
            let childEci = children[1]["eci"];
            let temperaturesUrl = "http://localhost:3000/c/" + eci + "/query/test_harness/temperatures";
            setTimeout(function() {
                document.getElementById('content').innerHTML += "20 seconds - verifying temperatures are being recorded</br>";
                post(temperaturesUrl, {"eci" : childEci}, 122, "temperatures")
            }, 20000)

            setTimeout(function() {
                document.getElementById('content').innerHTML += "25 seconds - verifying temperatures are being recorded</br>";
                post(temperaturesUrl, {"eci" : childEci}, 1234, "temperatures")
            }, 25000)

            setTimeout(function() {
                document.getElementById('content').innerHTML += "40 seconds - verifying temperatures are being recorded</br>";
                post(temperaturesUrl, {"eci" : childEci}, 9845, "temperatures")
            }, 40000)

            setTimeout(function() {
                document.getElementById('content').innerHTML += "60 seconds - verifying temperatures are being recorded</br>";
                post(temperaturesUrl, {"eci" : childEci}, 3216, "temperatures")
            }, 60000)

            //verify sensor profile is set correctly
            setTimeout(function() {
                let sensorProfileUrl = "http://localhost:3000/c/" + eci + "/query/test_harness/sensor_profile";
                post(sensorProfileUrl, {"eci" : childEci}, 6512, "sensorProfile");
            }, 10000);

        });

    

    
    
}

function checkCount(data, expectedCount) {
    children = data;
    let count = 0;
    for (var key in data) {
        count++;
    }
    document.getElementById('content').innerHTML += "Verify count: Counted " + count + "; Expected: " + expectedCount + "</br>";
}

function post(path, parameters, id, postAction="none") {
    var form = $('<form id="form' + id + '"></form>');

    form.attr("method", "post");
    form.attr("action", path);

    $.each(parameters, function(key, value) {
        var field = $('<input></input>');

        field.attr("type", "hidden");
        field.attr("name", key);
        field.attr("value", value);

        form.append(field);
    });

    $(document.body).append(form);
    SubForm(path, form, postAction);
}

function SubForm (path, form, postAction){
    $.ajax({
        url: path,
        type: 'post',
        data: form.serialize(),
        success: function(data) {
            if (postAction == "temperatures") {
                checkCount(data, 1);
            } else if (postAction == "sensorProfile") {
                verifyProfile(data);
            }
            
        }
    });
}

function verifyProfile(data) {
    content = document.getElementById('content');
    content.innerHTML += "Actual name: " + data["sensor_name"] + " ; Expected Name: Sensor 1 Pico</br>";
    content.innerHTML += "Actual phone number: " + data["phone_number"] + " ; Expected phone number: +13854502647</br>";
    content.innerHTML += "Actual location: " + data["sensor_location"] + " ; Expected location: noLocationSet</br>";
    content.innerHTML += "Actual temperature threshold: " + data["temperature_threshold"] + " ; Expected temperature threshold: 90</br>";
}

document.getElementById('test').addEventListener('click', onClick);