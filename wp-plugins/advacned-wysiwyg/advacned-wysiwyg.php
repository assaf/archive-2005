<?php
/*
Plugin Name: Advanced WYSIWYG Editor
Plugin URI: http://www.labnotes.org/
Description: Adds more styling options to the WYSIWYG post editor.
Version: 0.1
Author: Assaf Arkin
Author URI: http://labnotes.org/
License: Creative Commons Attribution-ShareAlike
Tags: wordpress tinymce
*/

if (isset($wp_version)) {
    add_filter("mce_plugins", "extended_editor_mce_plugins", 0);
    add_filter("mce_buttons", "extended_editor_mce_buttons", 0);
}


function extended_editor_mce_plugins($plugins) {
    array_push($plugins, "table", "fullscreen");
    return $plugins;
}


function extended_editor_mce_buttons($buttons) {
return array(
        "formatselect", "bold", "italic", "underline", "strikethrough", "separator",
        "bullist", "numlist", "indent", "outdent", "separator",
        "justifyleft", "justifycenter", "justifyright", "justifyfull", "separator",
        "link", "unlink", "anchor", "image", "hr", "separator",
        "cut", "copy", "paste", "undo", "redo", "separator",
        "table", "sub", "sup", "forecolor", "backcolor", "charmap", "separator",
        "code", "fullscreen", "wordpress", "wphelp");
}

?>