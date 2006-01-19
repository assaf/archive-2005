<?php
/*
Plugin Name: uPress
Plugin URI: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/WPPlugin/uPress
Description: Post events on your blog.
Version: 0.3
Author: Assaf Arkin
Author URI: http://labnotes.org/
License: Creative Commons Attribution-ShareAlike
Tags: microformats, microcontent, blogging
*/


if (isset($wp_version)) {

    add_action("admin_head", "upress_admin_header");
    add_action("edit_post", "upress_edit_post");
    add_action("save_post", "upress_edit_post");
    add_action("edit_form_advanced", "upress_edit_form");

    // Post formatting adds microformatting.
    add_filter("the_content", "upress_format_post", 9);
    add_filter("the_excerpt", "upress_format_post", 9);
    add_filter("the_excerpt_rss", "upress_format_post", 9);
}


$UPRESS_ADDRESS_PATTERN = "/((?#address)(?:\d{1,5}(?:[ ]+\w+\.?){1,})|(?:(?:pob|p\.o\.box)\s*\d{1,5}))((?#address2)(?:\s*(?:[,\n])\s*(?:(?:(?:#|apt|bldg|dept|fl|hngr|lot|pier|rm|s(?:lip|pc|t(?:e|op))|trlr|unit|room)\s*#?\s*[\w\-\/]+)|(?:bsmt|frnt|lbby|lowr|ofc|ph|rear|side|uppr)\.?)){0,2})\s*(?:[,\n])\s*((?#city)(?:[A-Za-z]{2,}\.?\s*){1,})\s*(?:[,\n])\s*((?#state)A[LKSZRAP]|C[AOT]|D[EC]|F[LM]|G[AU]|HI|I[ADLN]|K[SY]|LA|M[ADEHINOPST]|N[CDEHJMVY]|O[HKR]|P[ARW]|RI|S[CD]|T[NX]|UT|V[AIT]|W[AIVY])\s*((?#zipcode)(?<!0{5})\d{5}(-\d{4})?)?/iS";

$UPRESS_LOCATION_META_FIELDS = array("address1", "address2", "city", "region", "zipcode");

class uPressLocation {

    function parse_address($matches) {
        global $UPRESS_LOCATION_META_FIELDS;
        for ($i = 1; $i < $UPRESS_LOCATION_META_FIELDS.length; ++$i) {
            $UPRESS_LOCATION_META_FIELDS[$i] = $matches[$i];
            $matches[$i] = htmlspecialchars(trim($matches[$i]));
        }
        $address = $matches[1].", ".$matches[3].", ".$matches[4]." ".$matches[5];
        $this->link_to_map = "<a href=\"http://maps.google.com/maps?q=".urlencode($address)."\">Map It!</a>";
        $uformatted = "<div class='adr'><span class='street-address'>{$matches[1]}</span>";
        if ($matches[2])
            $uformatted .= " <span class='extended-address'>{$matches[2]}</span>";
        $uformatted .= "<div class='locality'>{$matches[3]}</div><div><span class='region'>{$matches[4]}</state> <span class='postal-code'>{$matches[5]}</span></div></div>";
        return $uformatted;
//    $address = str_replace("\n", ",", $matches[0]);
//    return "<a href=\"".htmlentities($textagsOptions["mapUrl"]).urlencode($address)."\">".htmlentities($matches[0])."</a>";
    }

}

function upress_process_location($location) {
    $result = new uPressLocation();
    $location = stripslashes(trim($location));
    if (!empty($location)) {
        global $UPRESS_ADDRESS_PATTERN;
        $result->uformatted = preg_replace_callback($UPRESS_ADDRESS_PATTERN, array($result, 'parse_address'), $location);
    }
    return $result;
}



/**
 * Event handling class and global methods.
 */
$UPRESS_META_FIELDS = array("dtstart", "dtend", "location");

$UPRESS_SECONDS_IN_DAY = 86400;

class uPressEvent {

    // Returns true if this event is valid. A valid event has a valid start
    // date/time, and either absent or valid end date/time.
    function is_valid() {
        return $this->valid_dt;
    }

    // Returns a microformat (hCal) representation of this event information.
    // Returns HTML for the event start date/time, end date/time and location.
    // Does not return the summary, description or outer vEvent parts.
    function microformat() {
        $html = "<div><strong>Starts:</strong> <abbr title=\"".$this->dtstart_iso."\" class=\"dtstart\">".$this->dtstart_text."</abbr></div>";
        if ($this->dtend_iso)
            $html .= "<div><strong>Ends:</strong> <abbr title=\"".$this->dtend_iso."\" class=\"dtend\">".$this->dtend_text."</abbr></div>";
        if (!empty($this->location))
            $html .= "<div class='location'><strong>Location</strong>: <span style=\"float:right\">{$this->address->link_to_map}</span>{$this->address->uformatted}</div>";
        return $html;
    }

    function ical($post, $content) {
        $ical = "BEGIN:VEVENT\nDTSTART:{$this->dtstart_iso}\n";
        if ($this->dtend_iso)
            $ical .= "DTEND:{$this->dtstart_iso}\n";
        $ical .= "DTSTAMP:".date("Ymd\THis", strtotime($post->post_date))."\nSUMMARY:".preg_replace("/,/", "\\,", $post->post_title)."\nDESCRIPTION:".preg_replace("/\n/", "\\n", $content)."\nEND:VEVENT\n";
        return $ical;
    }

}

function upress_load_from_post($post_id) {
    global $UPRESS_META_FIELDS;
    $event = new uPressEvent();
    // Load all the meta fields from the post.
    foreach ($UPRESS_META_FIELDS as $field)
        $event->$field = get_post_meta($post_id, "_event_{$field}", true);
    // Validate the event date/time. This gives us the text to present
    // in the form in human readable form, and also any error messages,
    // e.g. about event being invalid.
    $result = upress_validate_event_dt($event->dtstart, $event->dtend);
    foreach ($result as $name=>$value)
        $event->$name = $value;
    // Validate the location. This gives us a map link if we can understand
    // the address.
    $event->address = upress_process_location($event->location);
    return $event;
}

function upress_update_from_request($post_id, $request) {
    global $UPRESS_META_FIELDS;
    $event = new uPressEvent();
    // Get all meta fields from the HTTP POST.
    foreach ($UPRESS_META_FIELDS as $field)
        $event->$field = stripslashes(trim($request["event_{$field}"]));
    // Validate the event date/time. This gives us the ISO representation
    // of the date/time, the value we want to store in the database for
    // meta-data queries.
    $result = upress_validate_event_dt($event->dtstart, $event->dtend);
    if ($result->dtstart_iso)
        $result->dtstart = $result->dtstart_iso;
    if ($result->dtend_iso)
        $result->dtend = $result->dtend_iso;
    // Store the event fields as post metadata.
    foreach ($UPRESS_META_FIELDS as $field) {
        $meta_key = "_event_${field}";
        $value = $event->$field;
        if (isset($value) && !empty($value)) {
            if (!update_post_meta($post_id, $meta_key, $value))
                add_post_meta($post_id, $meta_key, $value, true);
        } else
            delete_post_meta($post_id, $meta_key);
    }
}

// Fix the datetime representation. There's a few things strototime
// doesn't deal well with which are fixed here. Specifically:
//  * Commas are removed (e.g. Jan 1, 2005 -> Jan 1 2005)
//  * AM/PM are normalized (e.g. a.m -> am)
function upress_fix_datetime($dt) {
    return preg_replace(array('/,/', '/a.m/', '/p.m/'), array(' ', 'am', 'pm'), trim($dt));
}

// Validate the event date/time values and return all information
// we need to display the event information, or decide whether or
// not the event is valid.
//
// The result is an array with the following entries:
//  * dtstart_iso -- ISO representation of the start date/time if
//    the start date/time could be parsed
//  * dtstart_text -- Textual representation of the start date/time
//    if the start date/time could be parsed
//  * dtstart_message -- An error message if the start date/time
//    could not be parsed
//  * dtend_iso -- ISO representation of the end date/time if
//    the end date/time could be parsed
//  * dtend_text -- Textual representation of the end date/time
//    if the end date/time could be parsed
//  * dtend_message -- An error message if the end date/time
//    could not be parsed or validated with respect to the start
//  * valid_dt -- True if the event start date/time is valid and
//    the end date/time is valid or absent.
function upress_validate_event_dt($dtstart, $dtend) {
    global $UPRESS_SECONDS_IN_DAY;
    $result = array();
    // Determine if we have dtstart to parse, and then whether or
    // not we can parse it.
    $dtstart = upress_fix_datetime($dtstart);
    if (empty($dtstart)) {
        $dtstart = null;
    } else if (($dt = strtotime($dtstart)) == -1 || $dt === false) {
        $dtstart = null;
        $result['dtstart_message'] = "I don't understand the event start date/time.";
    } else {
        // Determine if dtstart is a date or a date/time. Ugly but it works.
        // For dates, you get 000000 even if you shift the base time.
        // For today/saturday, you get the same time as the (shifted) base time.
        $base = time();
        $a_date = (date("His", strtotime($dtstart, $base)) == "000000" && date("His", strtotime($dtstart, $base + $UPRESS_SECONDS_IN_DAY - 1)) == "000000") ||
            (date("His", strtotime($dtstart, $base)) == date("His", $base) && date("His", strtotime($dtstart, $base + $UPRESS_SECONDS_IN_DAY - 1)) == date("His", $base + $UPRESS_SECONDS_IN_DAY - 1));

        // Create ISO/human representation of dtstart.
        $timeZone = upress_get_iso_timezone();
        $dtstart_real = strtotime($dtstart, upress_get_base_time());
        $result['dtstart_iso'] = $a_date ? date("Ymd", $dtstart_real) : date("Ymd\THis", $dtstart_real).$timeZone;
        $result['dtstart_text'] = $a_date ? date("F j, Y", $dtstart_real) : date("g:i a, F j, Y", $dtstart_real);
        $result['valid_dt'] = true;
    }

    // Determine if we have dtend to parse, and then whether or
    // not we can parse it. It is an error if dtstart is missing.
    $dtend = upress_fix_datetime($dtend);
    if (!empty($dtend)) {
        if (($dt = strtotime($dtend)) == -1 || $dt === false) {
            $result['dtend_message'] = "I don't understand the event end date/time.";
            $result['valid_dt'] = false;
        } else if (!$dtstart)
            $result['dtend_message'] = "The event start date/time is missing.";
        else {
            $dtend_real = strtotime($dtend, $dtstart_real);
            if ($a_date) {
                // If dtstart is a date, then dtend must also be a date and must be at least a
                // day later than dtstart.
                if ($dtend_real >= $dtstart_real + $UPRESS_SECONDS_IN_DAY) {
                    $result['dtend_iso'] = date("Ymd", $dtend_real);
                    $result['dtend_text'] = date("F j, Y", $dtend_real);
                } else {
                    $result['dtend_message'] = "The event end date must be at least one day after the start date";
                }
            } else {
                // If dtstart is date/time, then dtend must be dtstart or later.
                if ($dtend_real >= $dtstart_real) {
                    $result['dtend_iso'] = date("Ymd\THis", $dtend_real).$timeZone;
                    $result['dtend_text'] = date("g:i a, F j, Y", $dtend_real);
                } else {
                    $result['dtend_message'] = "The event end date/time must be later than the start date/time";
                }
            }
        }
    }
    return $result;
}

// Returns the time zone in seconds. This is either the time zone
// configured for WP, or the time zone used by PHP.
function upress_get_timezone_seconds() {
    global $wp_version;
    if (isset($wp_version))
        return ((int)get_option("gmt_offset")) * 60;
    else
        return (int)date("Z");
}

// Returns the base time (i.e. now). This is the same time that will
// be used for the post, or the PHP system time.
function upress_get_base_time() {
    global $wp_version;
    if (isset($wp_version))
        return strtotime(the_date("Y-m-d", null, null, false)." ".get_the_time("H:i:s"));
    else
        return time();
}

// Return the ISO representation of the time zone. See get_timezone_seconds.
function upress_get_iso_timezone() {
    global $wp_version;
    if (isset($wp_version)) {
        $offset = (int)get_option("gmt_offset");
        return $offset == 0 ? 'Z' : ($offset < 0 ? "-" : "+").sprintf("%02d00", abs($offset));
    } else {
        $offset = (int)date("Z") / 60;
        return $offset == 0 ? 'Z' : ($offset < 0 ? "-" : "+").sprintf("%02d%02d", abs($offset / 60), abs($offset % 60));
    }
}



/**
 * WordPress filters and actions
 */

function upress_edit_form() {
    global $post_ID;
    $event = upress_load_from_post($post_ID);
?>
<div id="upress" class="dbx-group" >
<fieldset id="upress-event" class="dbx-box">
<h3 class="dbx-handle"><?php _e('Event') ?></h3>
<div class="dbx-content">
<p><?php _e('To create an event, start by entering the date/time (e.g. 5pm, Jan 1):') ?></p>
<table style="width:99%">
<tr>
<th scope="row" align="right"><label for="event_dtstart"><?php _e('Starts:'); ?></label></th>
<td width="100%"><input type="text" id="event_dtstart" name="event_dtstart" tabindex="6" size="30" value="<?php echo wp_specialchars($event->dtstart); ?>" /><span id="event_dtstart_message" style="margin-left:20px;color:red"><?php if ($event->dtstart_message) echo wp_specialchars($event->dtstart_message); ?></span></td>
</tr>
<tr>
<th scope="row" align="right"><label for="event_dtend"><?php _e('Ends:'); ?></label></th>
<td><input type="text" id="event_dtend" name="event_dtend" tabindex="6" size="30" value="<?php echo wp_specialchars($event->dtend); ?>" /><span id="event_dtend_message" style="margin-left:20px;color:red"><?php if ($event->dtend_message) echo wp_specialchars($event->dtend_message); ?></span></td>
</tr>
<tr>
<th scope="row" align="right" valign="top"><label for="event_location"><?php _e('Location:'); ?></label></th>
<td><div id="event_location_map" style="float:right"><?php echo $event->address->link_to_map; ?></div><textarea rows="3" cols="60" type="text" id="event_location" name="event_location" tabindex="6"><?php echo wp_specialchars($event->location); ?></textarea></td>
</tr>
</table>
</div>
</fieldset>
</div>
<?php
}

function upress_edit_post($post_id) {
    upress_update_from_request($post_id, $_POST);
}

function upress_format_post($html) {
    global $post_ID, $post;
    $post_id = $post ? $post->ID : $post_ID;
    $event = upress_load_from_post($post_id);
    if ($event->is_valid()) {
        $ical = "BEGIN:VCALENDAR\nVERSION:1.0\nMETHOD:PUBLISH\nPRODID:-//uPress//upress.labnotes.org//EN\n".$event->ical($post, preg_replace("/\n/", "\\n", strip_tags($html)))."\nEND:VCALENDAR";
        $ical = "<a href=\"data:text/calendar,".preg_replace("/\n/", "%0a", $ical)."\" class=\"ical\" title=\"Add this event to you calendar\">iCal</a>";
        return "<div class='vevent'><div class='summary' style='display:none'>{$post->post_title}</div>".$event->microformat()."<div class='description'>".$html."</div></div>";
    } else
        return $html;
}


function upress_admin_header() {
    // Require prototype.js for all sort of AJAX goodness.
    $base_url = htmlentities(get_settings('siteurl').'/wp-content/plugins/upress/');
    echo "<link rel=\"stylesheet\" href=\"".wp_specialchars($base_url)."upress.css\" type=\"text/css\" />";
    echo "<script type=\"text/javascript\" src=\"".wp_specialchars($base_url)."prototype.js\"></script>";
    echo "<script type=\"text/javascript\"><!--\n";
    echo "var Labnotes = Labnotes || {}; Labnotes.uPress = Labnotes.uPress || {}; Labnotes.uPress.servicesURL = \"".wp_specialchars($base_url)."services.php\"";
    echo "\n--></script>";
    echo "<script type=\"text/javascript\" src=\"".wp_specialchars($base_url)."upress.js\"></script>";
}

?>