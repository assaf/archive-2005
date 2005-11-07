<?php
/*
Plugin Name: Textags
Plugin URI: http://www.labnotes.org/textags
Description: Easily create microcontents using <a href="http://www.labnotes.org/textags">Textags</a>
Version: 0.4
Author: Assaf Arkin
Author URI: http://labnotes.org/
License: Creative Commons Attribution-ShareAlike
Tags: textags, microformats, relTag, hCalendar
*/


// Do not change these defaults. Use the administration panel to configure the Textags options.

// Formatting for a Textag. The parameter $1 is replaced with the Textag name, the
// parameter $2 is replaced with the Textag content.
define("TEXTAGS_DEFAULT_FORMAT", "<p><em class=\"textag\">$1:</em> $2</p>");
// Formatting for a relTag link. The parameter $1 is replaced with the urlencoded
// tag for use in the URL; the parameter $2 is replaced with the htmlencoded tag
// for use in the content/title.
define("TEXTAGS_DEFAULT_RELTAG", "<a href=\"#tag/$1\" rel=\"tag\" class=\"tag\">$2</a>");
// Base URL for a relTag link. The tag is added to the end of the URL.
define("TEXTAGS_DEFAULT_RELTAG_URL", "http://en.wikipedia.org/wiki/");
// How to handle the Textag case.
// 0 = no change.
// 1 = upper case first letter.
// 2 = all upper case.
// 3 = all lower case.
define("TEXTAGS_DEFAULT_CASE", 1);
// Formatting for an hCalendar event. The parameter $1 is replaced with the event
// details (when, where, url, etc). The parameter $2 is replaced with the event
// description (everything that follows the event Textags). 
define("TEXTAGS_DEFAULT_VEVENT", "<div class=\"vevent\"><div class=\"details\">$1</div><div class=\"description\">$2</div></div>");
// Map service URL. Provides the URL for linking to a map service (e.g. Google).
// The address will be tacked to the end of the URL.
define("TEXTAGS_DEFAULT_MAPURL", "http://maps.google.com/maps?q=");

define("TEXTAGS_ADDRESS_PATTERN", '/((?#address)(?:\d{1,5}(?:\s+\w+\.?){1,})|(?:(?:pob|p\.o\.box)\s*\d{1,5}))((?#address2)(?:\s+(?:(?:(?:#|apt|bldg|dept|fl|hngr|lot|pier|rm|s(?:lip|pc|t(?:e|op))|trlr|unit)\s*#?\s*\w{1,5})|(?:bsmt|frnt|lbby|lowr|ofc|ph|rear|side|uppr)\.?)){0,2})\s*(?:[,\n])\s*((?#city)(?:[A-Za-z]{2,}\.?\s*){1,})\s*(?:[,\n])\s*((?#state)A[LKSZRAP]|C[AOT]|D[EC]|F[LM]|G[AU]|HI|I[ADLN]|K[SY]|LA|M[ADEHINOPST]|N[CDEHJMVY]|O[HKR]|P[ARW]|RI|S[CD]|T[NX]|UT|V[AIT]|W[AIVY])\s*((?#zipcode)(?<!0{5})\d{5}(-\d{4})?)?/iS');


// ---------------------------------------------
//  TexTags content filters
// ---------------------------------------------


// Called to process the raw text. Called before any other filters that my add markup
// to the text (e.g. markdown, textile, auto paragraphs).
function TextagsProcess($text) {
    // Convert all lines to end with NL before processing Textags.
    $text = str_replace(array("\r\n", "\r"), "\n", $text);
    $lines = explode("\n", $text);
    $count = count($lines);
    $output = array();
    $event = null;
    for ($i = 0; $i < $count; ++$i) {
        $line = $lines[$i];
        if (preg_match("/^(tags):\s*(\S+.*)$/i", $line, $matches)) {
            $output[] = TextagsProcessTags($matches);
            $skip = 1;
        } else if (preg_match("/^(link):\s*(\w+:\S+)(.*)$/i", $line, $matches)) {
            $output[] = TextagsProcessLink($matches);
            $skip = 1;
        } else if (!$event && preg_match("/^(when):\s*(\S+.*)$/i", $line, $matches)) {
            $skip = TextagsProcessEvent($matches, $lines, $i, null, $event);
            if ($event)
                $output[] = "<!--event-->".$event."<!--event-->";
        } else if (!$event && preg_match("/^what:\s*\S+.*$/i", $line) && ($i + 1 < $count) && preg_match("/^(when):\s*(\S+.*)$/i", $lines[$i + 1], $matches)) {
            $skip = TextagsProcessEvent($matches, $lines, $i, $line, $event);
            if ($event)
                $output[] = "<!--event-->".$event."<!--event-->";
        } else
            $skip = 0;
        if ($skip)
            $i += $skip - 1;
        else
            $output[] = $line;
    }
    return implode("\n", $output);
}


// Called to create the hCalendar template when the content is an event.
function TextagsEventFormat($text) {
    global $textagsOptions;
    return preg_replace("/<!--event-->(.*)<!--event-->(.*)/s", $textagsOptions["vevent"], $text);
}


// Called to process an event in response to the when: Textag. The matches array contains
// the full line (0), the Textag name (1) and the tags (2). We also pass all the lines in
// the source and the current index to allow consuming subsequent lines (ends:, where:, etc).
// If the what: Textag occurs before when:, that full line is passed as the last argument.
// The function returns the number of lines consumed, including the when: and what: lines,
// and sets the event object to hold the event details. It returns zero if the event cannot
// be processed.
function TextagsProcessEvent(&$matches, &$lines, $i, $whatLine, &$event) {
    // Calculate the start time relative to the current time (of this post, if known).
    // If the start time is invalid, do not process the event.
    $timeZone = TextagsGetISOTimeZone();
    $dtstart = strtotime($matches[2], TextagsGetBaseTime());
    if ($dtstart < 0)
        return 0;
    $event = TextagsFormat($matches[1], "<abbr title=\"".date("Y-m-d\TH:i:s", $dtstart).$timeZone."\" class=\"dtstart\">".htmlentities($matches[2])."</abbr>");

    // If the what: Textag precedes the when:, we skip two lines (we already read the
    // what: line) and add it at the beginning of the event.
    if ($whatLine) {
        preg_match("/^(what):\s*(\S+.*)$/i", $whatLine, $matches);
        $event = TextagsFormat($matches[1], "<span class=\"summary\">".trim($matches[2])."</span>").$event;
    }
    $skip = $whatLine ? 2 : 1;
    // If the ends: Textag follow next, process the end time (must be valid, or we ignore).
    if (isset($lines[$i + $skip]) && preg_match("/^(ends):\s*(\S+.*)$/i", $lines[$i + $skip], $matches) && ($dtend = strtotime($matches[2], $dtstart)) > 0) {
        $event .= TextagsFormat($matches[1], "<abbr title=\"".date("Y-m-d\TH:i:s", $dtend).$timeZone."\" class=\"dtend\">".htmlentities($matches[2])."</abbr>");
        ++$skip;
    }

    // What follows next are the what:, where:, url: and contact: Textags. We allow them
    // to appear in any order, but only once.
    $where = $url = $contact = false;
    $what = !$whatLine;
    while (isset($lines[$i + $skip])) {
        $line = $lines[$i + $skip];
        if (!$what && preg_match("/^(what):\s*(\S+.*)$/i", $line, $matches)) {
            $event .= TextagsFormat($matches[1], "<span class=\"summary\">".trim($matches[2])."</span>");
            $what = true;
        } else if (!$url && preg_match("/^(url):\s*(\w+:\S+)(.*)$/i", $line, $matches)) {
            $event .= TextagsProcessLink($matches);
            $url = true;
        } else if (!$where && preg_match("/^(where):\s*(\S+.*)$/i", $line, $matches)) {
            $location = $matches[2];
            while (isset($lines[$i + $skip + 1])) {
                $next = $lines[$i + $skip + 1];
                if ($next && !preg_match("/^<|\w+:/", $next)) {
                    $location .= "\n".$next;
                    ++$skip;
                } else
                    break;
            }
            $location = preg_replace_callback(TEXTAGS_ADDRESS_PATTERN, "TextagsMapAddress", $location);
            $location = str_replace("\n", "<br />", $location);
            $event .= TextagsFormat($matches[1], "<span class=\"location\">".$location."</span>");
            $where = true;
        } else if (!$contact && preg_match("/^(contact):\s*(\S+.*)$/i", $line, $matches)) {
            $contact = $matches[2];
            while (isset($lines[$i + $skip + 1])) {
                $next = $lines[$i + $skip + 1];
                if ($next && !preg_match("/^<|\w+:/", $next)) {
                    $contact .= "<br />".$next;
                    ++$skip;
                } else
                    break;
            }
            $event .= TextagsFormat($matches[1], "<span class=\"contact\">".$contact."</span>");
            $contact = true;
        } else
            break;
        ++$skip;
    }    
    return $skip;
}


// Called to create a link from an address. The unformatted address is provided in
// index 0. Indexes 0-5 provide the address components (primary, secondary, city, state,
// zipcode). If the zipcode is missing, then index 5 is unset.
function TextagsMapAddress($matches) {
    global $textagsOptions;
    $address = str_replace("\n", ",", $matches[0]);
    return "<a href=\"".htmlentities($textagsOptions["mapUrl"]).urlencode($address)."\">".htmlentities($matches[0])."</a>";
}


// Called to process the tags: Textag. The matches array contains the full line (0),
// the Textag name (1) and the tags (2). Returns the HTML formatted line.
function TextagsProcessTags(&$matches) {
    // Find all the tags in the line. Tags are separated by spaces or commas, quoting can be
    // used for multi-word tags
    preg_match_all("/(?:\"[^\"]*\")|(?:\"[^\"]*$)|(?:[^\",]+,)|(?:\S+)/", $matches[2], $tags);
    $entTags = null;
    foreach ($tags[0] as $tag) {
        // If the tag starts with a quote but the closing quote is missing, add it.
        if ($tag[0] == '"' && $tag[strlen($tag) - 1] != '"')
            $tag .= '"';
        // Process the tag into a link.
        $entTags .= preg_replace_callback("/^(\")?([^\",]+)([\",])?$/", "TextagsProcessTag", $tag);
        
    }
    return TextagsFormat($matches[1], $entTags);
}


// Called by TextagsProcessTags to transform a single tag into a relTag link.
function TextagsProcessTag(&$matches) {
    global $textagsOptions;
    preg_match_all("/\S+/", $matches[2], $parts);
    $tagId = implode(" ", $parts[0]);    
    return " ".$matches[1].str_replace(array("$1", "$2"), array($textagsOptions["relTagUrl"].urlencode($tagId), htmlentities($tagId)), $textagsOptions["relTag"]).$matches[3];    
}


// Called to process the link: and url: Textags. The matches array contains the full line (0),
// the Textag name (1), the URL (2) and anything else (3). Returns the HTML formatted line.
function TextagsProcessLink(&$matches) {
    $url = htmlentities($matches[2]);
    $title = htmlentities(trim($matches[3]));
    $value = "<a href=\"{$url}\" title=\"{$title}\" class=\"url\">{$url}</a> {$title}";
    return TextagsFormat($matches[1], $value);
}


// Formats a Texttag name/value pair into HTML. Transforms the Textag name based on
// the casing option, and applies the specified styling.
function TextagsFormat($textag, $value) {
    global $textagsOptions;
    switch ($textagsOptions["case"]) {
        case 1:
            $textag = ucfirst(strtolower($textag));
            break;
        case 2:
            $textag = strtoupper($textag);
            break;
        case 3:
            $textag = strtolower($textag);
            break;
    }
    return str_replace(array("$1", "$2"), array($textag, $value), $textagsOptions["format"]); 
}


// Gets the base time for events that use relative times (e.g. 'saturday', '5 hours').
// In WordPress it returns the time at which the event was created, otherwise it returns
// the current time.
function TextagsGetBaseTime() {
    global $wp_version;
    if (isset($wp_version))
        return strtotime(the_date("Y-m-d", null, null, false)." ".get_the_time("H:i:s"));
    else
        return time();
}


// Gets the timezone for events. In WordPress it uses the GMT offset property, otherwise
// it returns the timezone known to PHP. The timezone is returned in the format '+/-HHMM',
// or 'Z' if UTC.
function TextagsGetISOTimeZone() {
    global $wp_version;
    if (isset($wp_version)) {
        $offset = (int)get_option("gmt_offset");
        return $offset == 0 ? 'Z' : ($offset < 0 ? "-" : "+").sprintf("%02d:00", abs($offset));
    } else {
        $offset = (int)date("Z") / 60;
        return $offset == 0 ? 'Z' : ($offset < 0 ? "-" : "+").sprintf("%02d:%02d", abs($offset / 60), abs($offset % 60)); 
    }
}


// ---------------------------------------------
//  WordPress specific functions
// ---------------------------------------------

// Install WP actions and filters.
if (isset($wp_version)) {
    add_action('admin_menu', 'TextagsWPAdminMenu');
    // TODO: need to check these are the only places to add the filter.
    add_filter('the_content', 'TextagsProcess', 1);
    add_filter('the_excerpt', 'TextagsProcess', 1);
    add_filter('the_excerpt_rss', 'TextagsProcess', 1);
    add_filter('the_content', 'TextagsEventFormat', 9);
    add_filter('the_excerpt', 'TextagsEventFormat', 9);
    add_filter('the_excerpt_rss', 'TextagsEventFormat', 9);
    // TODO: need to check these are the only places to add the action.
    add_action('edit_form_advanced', 'TextagsWPHelp');
    add_action('edit_page_form', 'TextagsWPHelp');
    add_action('simple_edit_form', 'TextagsWPHelp');

    // Create options in WP database when the plugin is activated.
    if (isset($_GET["activate"])) {
        add_option("textags_format", TEXTAGS_DEFAULT_FORMAT, "Formatting template for Textag lines", "yes");
        add_option("textags_reltag", TEXTAGS_DEFAULT_RELTAG, "Template for relTag links", "yes");
        add_option("textags_reltagurl", TEXTAGS_DEFAULT_RELTAG_URL, "Base URL for relTag links", "yes");
        add_option("textags_vevent", TEXTAGS_DEFAULT_VEVENT, "Template for hCalendar events", "yes");
        add_option("textags_case", TEXTAGS_DEFAULT_CASE, "Case for Textags", "yes");
        add_option("textags_mapurl", TEXTAGS_DEFAULT_MAPURL, "Map service URL", "yes");
    }
    
    // Load the options from WP.
    global $textagsOptions;
    $format = get_option("textags_format") or TEXTAGS_DEFAULT_FORMAT;
    if (!$format)
        $format = TEXTAGS_DEFAULT_FORMAT;
    $relTag = get_option("textags_reltag");
    if (!$relTag)
        $relTag = TEXTAGS_DEFAULT_RELTAG;
    $relTagUrl = get_option("textags_reltagurl");
    if (!$relTagUrl)
        $relTagUrl = TEXTAGS_DEFAULT_RELTAG_URL;
    $vevent = get_option("textags_vevent");
    if (!$vevent)
        $vevent = TEXTAGS_DEFAULT_VEVENT;
    $case = (int)get_option("textags_case");
    $mapUrl = get_option("textags_mapurl");
    $textagsOptions = array("format"=>$format, "relTag"=>$relTag, "relTagUrl"=>$relTagUrl, "vevent"=>$vevent, "case"=>$case, "mapUrl"=>$mapUrl);
}


// Adds the Textags configuration panel to the admin menu.
function TextagsWPAdminMenu() {
    if (function_exists('add_options_page'))
        add_options_page('Textags Options', 'Textags', 1, basename(__FILE__), 'TextagsWPAdminPanel');
}


// WordPress administration panels for configuring Textags options.
function TextagsWPAdminPanel() {
    global $textagsOptions;
    if (isset($_POST["info_update"])) {
        $message = null;
        $format = isset($_POST["ttformat"]) ? trim(stripslashes($_POST["ttformat"])) : null;
        $relTag = isset($_POST["ttreltag"]) ? trim(stripslashes($_POST["ttreltag"])) : null;
        $relTagUrl = isset($_POST["ttreltagurl"]) ? trim(stripslashes($_POST["ttreltagurl"])) : null;
        $vevent = isset($_POST["ttvevent"]) ? trim(stripslashes($_POST["ttvevent"])) : null;
        $case = isset($_POST["ttcase"]) ? (int)$_POST["ttcase"] : 0;
        $mapUrl = isset($_POST["ttmapurl"]) ? trim(stripslashes($_POST["ttmapurl"])) : null;
        if (!$format)
            $message = "Please specify a valid Textags formatting template";
        else if (!$relTag)
            $message = "Please specify a valid relTag template";
        else if (!$vevent)
            $message = "Please specify a valid hCalendar template";
        else if ($case < 0 || $case > 3)
            $message = "Please select a valid Textags case option";
        if (!$message) {
            update_option("textags_format", $format);
            update_option("textags_reltag", $relTag);
            update_option("textags_reltagurl", $relTagUrl);
            update_option("textags_vevent", $vevent);
            update_option("textags_mapurl", $mapUrl);
            update_option("textags_case", $case);
            $message = "Options saved.";
        }
        $textagsOptions = array("format"=>$format, "relTag"=>$relTag, "relTagUrl"=>$relTagUrl, "vevent"=>$vevent, "case"=>$case, "mapUrl"=>$mapUrl);
?><div class="updated"><p><strong><?php _e($message) ?></strong></p></div><?php
    }
?>
<div class=wrap>
  <form method="post">
    <h2>Textags Options</h2>
    <!--
      <fieldset name="general" class="options">
        <legend><?php _e('General') ?></legend>
        <table width="100%" cellspacing="2" cellpadding="5" class="editform"> 
          <tr valign="top">
            <th scope="row" width="30%"> Enable Textags: </th>
            <td><input type="checkbox" name="ttenable" value="tags"> Tags:<br />
            <input type="checkbox" name="ttenable" value="link"> Links:<br />
            <input type="checkbox" name="ttenable" value="event"> Events (when:, where:, etc)<br />
            <input type="checkbox" name="ttenabledt" value="<?php date("Y-m-s"); ?>"> New posts only<br />
            </td>
          </tr>
        </table>
      </fieldset>
    -->
      <fieldset name="formatting" class="options">
        <legend><?php _e('Formatting') ?></legend>
	      <p>By default Textags are displayed with upper case first letter and lower case for all subsequent letters. For example, if the post uses the
        Textag <code>tags:</code>, it will show in the blog as <code>Tags:</code>. You can override this option to make the Textag all upper case,
        all lower case, or just leave it as it appears in the post.</p>
        <p>The default template for formatting Textags lines is <code><?php echo htmlentities(TEXTAGS_DEFAULT_FORMAT); ?></code>.
        You can change the template to a different format, e.g. to apply specific styling rules. The template uses two markers.
        The marker <code>$1</code> is replaced with the Textag name; the marker <code>$2</code> is replaced with the Textag value
        (the reminder of the line).</p>        
        <dl>
          <dt>Line format: <code><?php echo htmlentities(TEXTAGS_DEFAULT_FORMAT); ?></code></dt>
          <dd><strong>Result:</strong> <em>Tags:</em> <a href="#">textags</a> <a href="#">microformat</a> <a href="#">wp-plugin</a></dd>
        </dl>
        <p>The default template for formatting tags is <code><?php echo htmlentities(TEXTAGS_DEFAULT_RELTAG); ?></code>. It produces
        a tag link that conforms to the <a href="http://microformats.org/wiki/reltag">relTag</a> microformat. The template uses the marker
        <code>$1</code> for the URL encoding of the tag, and the marker <code>$2</code> for the HTML encoding.</p>
        <p>The default template for formatting events is <code><?php echo htmlentities(TEXTAGS_DEFAULT_VEVENT); ?></code>. It produces
        event information that conforms to the <a href="http://microformats.org/wiki/hcalendar">hCalendar</a> microformat. The template
        uses the marker <code>$1</code> for the event header (what, when, where, etc), and the marker <code>$2</code> for the event
        description.</p>

        <table width="100%" cellspacing="2" cellpadding="5" class="editform"> 
          <tr valign="top">
            <th scope="row" width="30%"> Textag case: </th>
            <td><select name="ttcase" size="1">
              <option value="0" <?php if ($textagsOptions["case"] == 0) echo "selected='selected'"; ?>>Leave unchanged</option>
              <option value="1" <?php if ($textagsOptions["case"] == 1) echo "selected='selected'"; ?>>First letter upper case</option>
              <option value="2" <?php if ($textagsOptions["case"] == 2) echo "selected='selected'"; ?>>All upper case</option>
              <option value="3" <?php if ($textagsOptions["case"] == 3) echo "selected='selected'"; ?>>All lower case</option>
            </select></td>
          </tr>
          <tr valign="top">
            <th scope="row"> Line format: </th>
            <td><input name="ttformat" type="text" size="60" value="<?php echo htmlentities($textagsOptions["format"]); ?>" /></td>
          </tr>
          <tr valign="top">
            <th scope="row"> relTag template: </th>
            <td><input name="ttreltag" type="text" size="60" value="<?php echo htmlentities($textagsOptions["relTag"]); ?>"/></td>
          </tr>
          <tr valign="top">
            <th scope="row"> hCalendar template: </th>
            <td><input name="ttvevent" type="text" size="60" value="<?php echo htmlentities($textagsOptions["vevent"]); ?>"/></td>
          </tr>
        </table>
      </fieldset>
      <fieldset name="misc" class="options">
        <legend><?php _e('Misc') ?></legend>
        <table width="100%" cellspacing="2" cellpadding="5" class="editform"> 
          <tr valign="top">
            <th scope="row" width="30%"> Tag base URL: </th>
            <td><input name="ttreltagurl" type="text" size="60" value="<?php echo htmlentities($textagsOptions["relTagUrl"]); ?>"/></td>
          </tr>
          <tr valign="top">
            <th scope="row" width="30%"> Map service URL: </th>
            <td><input name="ttmapurl" type="text" size="60" value="<?php echo htmlentities($textagsOptions["mapUrl"]); ?>"/></td>
          </tr>
        </table>
      </fieldset>
    <div class="submit">
    <input type="submit" name="info_update" value="<?php _e('Update options') ?> &raquo;" /></div>
  </form>
</div> <?php
}


// Provides pop-up help in the edit form. Works by inserting a link below the edit form
// that points to the help page included with the plugin and using JavaScript to open it
// in a new window.
function TextagsWPHelp() {
    $url = get_settings('siteurl');
    $url = htmlentities($url . '/wp-content/plugins/textags.html');
    echo <<<EOD
<script type="text/javascript">
<!--
var content = document.getElementById("content");
function openTextagsHelp() {
    open('{$url}', 'Textags help', 'width=600,height=600,scrollbars=yes');
}
if (content) {
    var help = document.createElement("p");
    help.setAttribute("align", "center");
    help.innerHTML = "You can use <a href='{$url}' onclick='openTextagsHelp();return false'>Textags</a> to create events, link to a site and tag your post.";
    content.parentNode.appendChild(help)
}
</script>
EOD;
}


?>
