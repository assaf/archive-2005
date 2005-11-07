<?php
/*
Plugin Name: TagsLinks
Plugin URI: http://trac.labnotes.org/
Description: Adds a dropdown list to all tags present on the page. The dropdown list redirects the user to tagging services, like like Del.icio.us, Flickr and Technorati. Requires tags to use the relTag microformat.
Version: 0.6
Author: Assaf Arkin
Author URI: http://labnotes.org/
License: Creative Commons Attribution-ShareAlike
Tags: relTag, tags
Site: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/TagsLinks
*/

if (isset($wp_version)) {
    add_action('wp_head', 'TagsLinksAddHeader');
}

function TagsLinksAddHeader() {
    $url = get_settings('siteurl');
    $url = htmlentities($url . '/wp-content/plugins/tagslinks/');
    echo <<<EOD
<style type="text/css" media="screen">
  @import url( '{$url}tagslinks.css' );
.labnotes_transoverlay {
  border: 1px solid black;
  background: white;
  position: absolute;
  visibility: hidden;
  margin: 20px 0 20px 0;
  padding: 5px;
  font-family: Verdana, 'Lucida Grande', Arial, Sans-Serif;
  font-size: 10px;
}
</style>
<script type="text/javascript" src="{$url}behaviour.js"></script>
<script type="text/javascript" src="{$url}transoverlay.js"></script>
<script type="text/javascript" src="{$url}tagslinks.js"></script>
EOD;
}

?>
