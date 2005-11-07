<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<xsl:output method="html" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/> 
<xsl:template match="/rss">
<html xmlns="http://www.w3.org/1999/xhtml">
 	<head>
	<xsl:variable name="cssUrl" select="substring-after(substring-before(/processing-instruction('xml-stylesheet'),'&quot; type'), 'href=&quot;')"/>
    <style type="text/css" media="screen">
	    @import url(<xsl:copy-of select="string($cssUrl)"/>);
    </style>
		<script type="text/javascript"><![CDATA[
function decode() {
	var descs = document.getElementsByTagName("description");
	var count = descs.length;
	for (var i = 0; i < count; ++i) {
	  var node = descs[i];
		var text;
		if (typeof node.textContent != 'undefined')
			text = node.textContent;
		else if (typeof node.innerText != 'undefined')
			text = node.innerText;
		else if (typeof node.text != 'undefined')
			text = node.text;
		if (text)
			node.innerHTML = text;
	}
}]]></script>
  </head>
	<xsl:variable name="feedUrl" select="@xml:base"/>

  <body onLoad="decode()">
  <xsl:copy-of select="string($cssUrl)"/>
  	<channel>
	  	<xsl:copy-of select="channel/title"/>
      <div class="subscriptions">
			  <p><a href="http://en.wikipedia.org/wiki/RSS_%28file_format%29">RSS</a> stands for "Really Simple Syndication". It's used to distribute headlines, blog posts and listings to a large number of people. RSS makes it simple for Web sites to notify users of new and changed content, and for users to keep track of content coming from different sources. The easiest way to read (or subscribe) to RSS feeds is to use an <a href="http://en.wikipedia.org/wiki/RSS_Feed_Reader">RSS news reader</a> or RSS aggregator.</p>
				<h3>Subscribe</h3>
				<p>If you are using an RSS reader, click <a href="{concat('feed:',$feedUrl)}"><img src="/wp-images/rss-feed.gif" alt="RSS feed" /></a></p>
			  <p>You can also subscribe using <a href="{concat('http://www.bloglines.com/sub/',$feedUrl)}">
          <img src="http://www.bloglines.com/images/sub_modern5.gif" alt="Bloglines" /></a>, <a href="{concat('http://add.my.yahoo.com/rss?url=',$feedUrl)}">
          <img src="http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif" alt="My Yahoo!" /></a> or <a href="{concat('http://www.newsgator.com/ngs/subscriber/subext.aspx?url=',$feedUrl)}">
			    <img src="http://www.newsgator.com/images/ngsub1.gif" alt="NewsGator" /></a></p>
				<p>If these links do not work for you, copy this URL to your RSS reader/aggergator:
				<pre><xsl:copy-of select="string($feedUrl)"/></pre></p>
		  </div>
	    <xsl:apply-templates select="channel/item"/>
		</channel>
	</body>
  </html>
</xsl:template>

<xsl:template match="item">
  <item>
		<xsl:variable name="link" select="link/text()"/>	
	  <a href="{$link}"><xsl:copy-of select="title"/></a>
		<description>
			<xsl:copy-of select="content:encoded/text()"/>
		</description>
		<info>posted on <xsl:copy-of select="substring-before(pubDate/text(), '+')"/>
		  <xsl:variable name="count" select="count(category)"/>
			<xsl:if test="$count > 0"> in	</xsl:if>
	    <xsl:apply-templates select="category"/>
		</info>
	</item>
</xsl:template>

<xsl:template match="category">
  <category>
		<xsl:variable name="category" select="text()"/>
	  <a href="/category/{$category}"><xsl:value-of select="$category"/></a>
	</category>
</xsl:template>

</xsl:stylesheet>
