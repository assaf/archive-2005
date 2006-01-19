<?php
require_once(dirname(__FILE__).'/upress.php');


function output_json($object) {
    $output = null;
    foreach ($object as $name=>$value) {
        $output .= $output ? "," : "{";
        $value = preg_replace('/"/', '\\"', $value);
        $output .= "\"{$name}\": \"${value}\"";
    }
    if ($output)
        return $output."}";
    else
        return "{}";
}

$method = $_GET['method'];
switch ($method) {
case 'process_event':
    $result = upress_validate_event_dt($_GET['dtstart'], $_GET['dtend']);
    echo output_json($result);
    break;
case 'process_location':
    $result = upress_process_location($_GET["location"]);
    echo output_json($result);
    break;
}
?>