var Labnotes = Labnotes || {};
Labnotes.uPress = Labnotes.uPress || {};

Labnotes.uPress.dateProcessing = function() {
    var dtstart = $("event_dtstart");
    var dtend = $("event_dtend");
    function changeEvent() {
        var dtstart_old = dtstart.value;
        var dtend_old = dtend.value;
        var options = {
            method: "get",
            parameters: "method=process_event&dtstart=" + encodeURIComponent(dtstart.value) + "&dtend=" + encodeURIComponent(dtend.value),
            onSuccess: function(response) {
                var json;
                eval("json=" + response.responseText);
                if (dtstart_old == dtstart.value && dtend_old == dtend.value) {
                    $("event_dtstart_message").innerHTML = json["dtstart_message"] ? json["dtstart_message"] : null;
                    $("event_dtend_message").innerHTML = json["dtend_message"] ? json["dtend_message"] : null;
                    if (json["dtstart_text"])
                        dtstart.value = json["dtstart_text"];
                    if (json["dtend_text"])
                        dtend.value = json["dtend_text"];
                }
            },
            onFailure: function() {
                $("event_dtstart_message").innerHTML = null;
                $("event_dtend_message").innerHTML = null;
            }
        };
        new Ajax.Request(Labnotes.uPress.servicesURL, options);
    }
    new Form.Element.EventObserver(dtstart, changeEvent);
    new Form.Element.EventObserver(dtend, changeEvent);
}

Labnotes.uPress.locationProcessing = function() {
    var location = $("event_location");
    var url = "<?php echo wp_specialchars($services); ?>";
    function changeEvent() {
        var location_old = location.value;
        var options = {
            method: "get",
            parameters: "method=process_location&location=" + encodeURIComponent(location.value),
            onSuccess: function(response) {
                var json;
                eval("json=" + response.responseText);
                if (location_old == location.value) {
                    $("event_location_map").innerHTML = json["link_to_map"] ? json["link_to_map"] : null;
                }
            },
            onFailure: function() {
                $("event_location_map").innerHTML = null;
            }
        };
        new Ajax.Request(Labnotes.uPress.servicesURL, options);
    }
    new Form.Element.EventObserver(location, changeEvent);
}

Event.observe(window, 'load', Labnotes.uPress.dateProcessing, false);
Event.observe(window, 'load', Labnotes.uPress.locationProcessing, false);

Labnotes.uPress.dbx = function() {
	new dbxGroup(
		'upress', 		// container ID [/-_a-zA-Z0-9/]
		'vertical', 		// orientation ['vertical'|'horizontal']
		'10', 			// drag threshold ['n' pixels]
		'yes',			// restrict drag movement to container axis ['yes'|'no']
		'10', 			// animate re-ordering [frames per transition, or '0' for no effect]
		'yes', 			// include open/close toggle buttons ['yes'|'no']
		'closed', 		// default state ['open'|'closed']
		'open', 		// word for "open", as in "open this box"
		'close', 		// word for "close", as in "close this box"
		'click-down and drag to move this box', // sentence for "move this box" by mouse
		'click to %toggle% this box', // pattern-match sentence for "(open|close) this box" by mouse
		'use the arrow keys to move this box', // sentence for "move this box" by keyboard
		', or press the enter key to %toggle% it',  // pattern-match sentence-fragment for "(open|close) this box" by keyboard
		'%mytitle%  [%dbxtitle%]' // pattern-match syntax for title-attribute conflicts
		);
}

Event.observe(window, 'load', Labnotes.uPress.dbx, false);



Labnotes.uPress.Listing = {
    toggle: function(enabled) {
        var inputs = $("upress-listing").getElementsByTagName("input");
        for (var i = 0; i < inputs.length; ++i) {
            if (inputs[i].name != "listing_type")
                inputs[i].disabled = !enabled;
        }
        inputs = $("upress-listing").getElementsByTagName("textarea");
        for (var i = 0; i < inputs.length; ++i)
            inputs[i].disabled = !enabled;
    }
};
