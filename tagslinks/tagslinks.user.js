// TagsLinks Greasemonkey script
// Copyright (C) 2005 Assaf Arkin http://labnotes.org
// Version 0.6
// License: Creative Commons Attribution-ShareAlike
//
// --------------------------------------------------------------------
//
// This is a Greasemonkey user script.
//
// To install, you need Greasemonkey: http://greasemonkey.mozdev.org/
// Then restart Firefox and revisit this script.
// Under Tools, there will be a new menu item to "Install User Script".
// Accept the default configuration and install.
//
// To uninstall, go to Tools/Manage User Scripts,
// select "Hello World", and click Uninstall.
//
// --------------------------------------------
//
// ==UserScript==
// @name          TagsLinks
// @namespace     http://labnotes.org/tagslinks
// @description   TagsLinks makes tags more useful by turning each tag into links that
// point to different tagging services. Instead of linking to one Web site, tags now
// link to content on del.icio.us, images on Flickr, blogs on Technorati, and more.
// @include       *
// ==/UserScript==


(function() {
/*
   Behaviour v1.0 by Ben Nolan, June 2005. Based largely on the work
   of Simon Willison (see comments by Simon below).

   Description:

   	Uses css selectors to apply javascript behaviours to enable
   	unobtrusive javascript in html documents.

   Usage:

	var myrules = {
		'b.someclass' : function(element){
			element.onclick = function(){
				alert(this.innerHTML);
			}
		},
		'#someid u' : function(element){
			element.onmouseover = function(){
				this.innerHTML = "BLAH!";
			}
		}
	);

	Behaviour.register(myrules);

	// Call Behaviour.apply() to re-apply the rules (if you
	// update the dom, etc).

   License:

   	My stuff is BSD licensed. Not sure about Simon's.

   More information:

   	http://ripcord.co.nz/behaviour/

*/

var Behaviour = {
	list : new Array,

	register : function(sheet){
		Behaviour.list.push(sheet);
	},

	start : function(){
		Behaviour.addLoadEvent(function(){
			Behaviour.apply();
		});
	},

	apply : function(){
        for (h=0;sheet=Behaviour.list[h];h++){
			for (selector in sheet){
				list = document.getElementsBySelector(selector);

				if (!list){
					continue;
				}

				for (i=0;element=list[i];i++){
					sheet[selector](element);
				}
			}
		}
	},

	addLoadEvent : function(func){
		var oldonload = window.onload;

		if (typeof oldonload != 'function') {
			window.onload = func;
		} else {
			window.onload = function() {
				oldonload();
				func();
			}
		}
	}
}

Behaviour.start();

/*
   The following code is Copyright (C) Simon Willison 2004.

   document.getElementsBySelector(selector)
   - returns an array of element objects from the current document
     matching the CSS selector. Selectors can contain element names,
     class names and ids and can be nested. For example:

       elements = document.getElementsBySelect('div#main p a.external')

     Will return an array of all 'a' elements with 'external' in their
     class attribute that are contained inside 'p' elements that are
     contained inside the 'div' element which has id="main"

   New in version 0.4: Support for CSS2 and CSS3 attribute selectors:
   See http://www.w3.org/TR/css3-selectors/#attribute-selectors

   Version 0.4 - Simon Willison, March 25th 2003
   -- Works in Phoenix 0.5, Mozilla 1.3, Opera 7, Internet Explorer 6, Internet Explorer 5 on Windows
   -- Opera 7 fails
*/

function getAllChildren(e) {
  // Returns all children of element. Workaround required for IE5/Windows. Ugh.
  return e.all ? e.all : e.getElementsByTagName('*');
}

document.getElementsBySelector = function(selector) {
  // Attempt to fail gracefully in lesser browsers
  if (!document.getElementsByTagName) {
    return new Array();
  }
  // Split selector in to tokens
  var tokens = selector.split(' ');
  var currentContext = new Array(document);
  for (var i = 0; i < tokens.length; i++) {
    token = tokens[i].replace(/^\s+/,'').replace(/\s+$/,'');;
    if (token.indexOf('#') > -1) {
      // Token is an ID selector
      var bits = token.split('#');
      var tagName = bits[0];
      var id = bits[1];
      var element = document.getElementById(id);
      if (tagName && element.nodeName.toLowerCase() != tagName) {
        // tag with that ID not found, return false
        return new Array();
      }
      // Set currentContext to contain just this element
      currentContext = new Array(element);
      continue; // Skip to next token
    }
    if (token.indexOf('.') > -1) {
      // Token contains a class selector
      var bits = token.split('.');
      var tagName = bits[0];
      var className = bits[1];
      if (!tagName) {
        tagName = '*';
      }
      // Get elements matching tag, filter them for class selector
      var found = new Array;
      var foundCount = 0;
      for (var h = 0; h < currentContext.length; h++) {
        var elements;
        if (tagName == '*') {
            elements = getAllChildren(currentContext[h]);
        } else {
            elements = currentContext[h].getElementsByTagName(tagName);
        }
        for (var j = 0; j < elements.length; j++) {
          found[foundCount++] = elements[j];
        }
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      for (var k = 0; k < found.length; k++) {
        if (found[k].className && found[k].className.match(new RegExp('\\b'+className+'\\b'))) {
          currentContext[currentContextIndex++] = found[k];
        }
      }
      continue; // Skip to next token
    }
    // Code to deal with attribute selectors
    if (token.match(/^(\w*)\[(\w+)([=~\|\^\$\*]?)=?"?([^\]"]*)"?\]$/)) {
      var tagName = RegExp.$1;
      var attrName = RegExp.$2;
      var attrOperator = RegExp.$3;
      var attrValue = RegExp.$4;
      if (!tagName) {
        tagName = '*';
      }
      // Grab all of the tagName elements within current context
      var found = new Array;
      var foundCount = 0;
      for (var h = 0; h < currentContext.length; h++) {
        var elements;
        if (tagName == '*') {
            elements = getAllChildren(currentContext[h]);
        } else {
            elements = currentContext[h].getElementsByTagName(tagName);
        }
        for (var j = 0; j < elements.length; j++) {
          found[foundCount++] = elements[j];
        }
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      var checkFunction; // This function will be used to filter the elements
      switch (attrOperator) {
        case '=': // Equality
          checkFunction = function(e) { return (e.getAttribute(attrName) == attrValue); };
          break;
        case '~': // Match one of space seperated words
          checkFunction = function(e) { return (e.getAttribute(attrName) && e.getAttribute(attrName).match(new RegExp('\\b'+attrValue+'\\b'))); };
          break;
        case '|': // Match start with value followed by optional hyphen
          checkFunction = function(e) { return (e.getAttribute(attrName) && e.getAttribute(attrName).match(new RegExp('^'+attrValue+'-?'))); };
          break;
        case '^': // Match starts with value
          checkFunction = function(e) { return (e.getAttribute(attrName) && e.getAttribute(attrName).indexOf(attrValue) == 0); };
          break;
        case '$': // Match ends with value - fails with "Warning" in Opera 7
          checkFunction = function(e) { return (e.getAttribute(attrName) && e.getAttribute(attrName).lastIndexOf(attrValue) == e.getAttribute(attrName).length - attrValue.length); };
          break;
        case '*': // Match ends with value
          checkFunction = function(e) { return (e.getAttribute(attrName) && e.getAttribute(attrName).indexOf(attrValue) > -1); };
          break;
        default :
          // Just test for existence of attribute
          checkFunction = function(e) { return e.getAttribute(attrName); };
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      for (var k = 0; k < found.length; k++) {
        if (checkFunction(found[k])) {
          currentContext[currentContextIndex++] = found[k];
        }
      }
      // alert('Attribute Selector: '+tagName+' '+attrName+' '+attrOperator+' '+attrValue);
      continue; // Skip to next token
    }

    if (!currentContext[0]){
    	return;
    }

    // If we get here, token is JUST an element (not a class or ID selector)
    tagName = token;
    var found = new Array;
    var foundCount = 0;
    for (var h = 0; h < currentContext.length; h++) {
      var elements = currentContext[h].getElementsByTagName(tagName);
      for (var j = 0; j < elements.length; j++) {
        found[foundCount++] = elements[j];
      }
    }
    currentContext = found;
  }
  return currentContext;
}

/* That revolting regular expression explained
/^(\w+)\[(\w+)([=~\|\^\$\*]?)=?"?([^\]"]*)"?\]$/
  \---/  \---/\-------------/    \-------/
    |      |         |               |
    |      |         |           The value
    |      |    ~,|,^,$,* or =
    |   Attribute
   Tag
*/


// TransOverlay.js
//
// Version 0.1
// Copyright (C) 2005 Assaf Arkin http://labnotes.org
// License: Creative Commons Attribution-ShareAlike
// http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/TransOverlay

var Labnotes;
if (!Labnotes) Labnotes = {};
if (!Labnotes.TransOverlay)
    Labnotes.TransOverlay = {
        overlay: null,
        default_delay: 100,
        next_event: null,
        timer: null,
        safe_box: null,
        display_timer: null,

        // Called once to initialize everything.
        initialize: function() {
            // Register onload event.
            if (document.addEventListener)
                window.addEventListener("load", Labnotes.TransOverlay.onload, true);
            else if (document.attachEvent)
                window.attachEvent("onload", Labnotes.TransOverlay.onload);
            else {
                var old_onload = window.onload;
                if (old_onload) {
                    window.onload = function() {
                        old_onload(document);
                        Labnotes.TransOverlay.onload();
                    }
                } else
                    window.onload = Labnotes.TransOverlay.onload;
            }
        },

        onload: function() {
            if (!Labnotes.TransOverlay.overlay) {
                // Create overlay ovject.
                var overlay = document.createElement('div');
                overlay.className = 'labnotes_transoverlay';
                overlay.style.visibility = 'hidden';
                overlay.style.position = 'absolute';
                Labnotes.TransOverlay.overlay = overlay;
                document.body.appendChild(overlay);
                // Register onmousemove event.
                if (document.addEventListener)
                    document.addEventListener("mousemove", Labnotes.TransOverlay.mousemove, true);
                else if (document.attachEvent)
                    document.attachEvent("onmousemove", Labnotes.TransOverlay.mousemove);
                else {
                    var old_mousemove = document.mousemove;
                    if (old_mousemove) {
                        document.mousemove = function() {
                            old_mousemove(document);
                            Labnotes.TransOverlay.mousemove();
                        }
                    } else
                        document.mousemove = Labnotes.TransOverlay.mousemove;
                    if (document.captureEvents)
                        document.captureEvents(Event.MOUSEDOWN);
                }
            }
        },

        // Find the bounding box for an element as absolute coordinates.
        // Returns array with left, right, top and bottom bounding coordinates.
        box_from_element: function(element) {
            var left = element.offsetLeft;
            var top = element.offsetTop;
            var parent = element.offsetParent;
            while (parent != null) {
                left += parent.offsetLeft
                top += parent.offsetTop;
                parent = parent.offsetParent;
            }
            return [left, left + element.offsetWidth, top, top + element.offsetHeight];
        },

        mousemove: function(event) {
            if (!event)
                event = window.event;
            var safebox = Labnotes.TransOverlay.safebox;
            if (safebox) {
                var overlay = Labnotes.TransOverlay.overlay;
                var clientX = event.clientX;
                var clientY = event.clientY;
                if (window.pageXOffset || window.pageYOffset) {
                    clientX += window.pageXOffset;
                    clientY += window.pageYOffset;
                } else if (event.x && event.y) {
                    clientX = event.x + document.body.scrollLeft + document.body.parentNode.scrollLeft;
                    clientY = event.y + document.body.scrollTop + document.body.parentNode.scrollTop;
                }
                var distX, distY;
                if (clientX < safebox[0])
                    distX = safebox[0] - clientX;
                else if (clientX > safebox[1])
                    distX = clientX - safebox[1];
                else
                    distX = 0;
                if (clientY < safebox[2])
                    distY = safebox[2] - clientY;
                else if (clientY > safebox[3])
                    distY = clientY - safebox[3];
                else
                    distY = 0;
                if (!Labnotes.TransOverlay.timer)
                    Labnotes.TransOverlay.queue('opacity', Labnotes.TransOverlay.calc_opacity(Math.sqrt(distX^2 + distY^2)));
            }
        },

        queue: function(type, data, delay) {
            if (Labnotes.TransOverlay.timer) {
                window.clearTimeout(Labnotes.TransOverlay.timer);
                Labnotes.TransOverlay.timer = null;
            }
            Labnotes.TransOverlay.next_event = [type, data];
            if (!Labnotes.TransOverlay.timer)
                Labnotes.TransOverlay.timer = window.setTimeout(Labnotes.TransOverlay.dequeue, delay ? delay : Labnotes.TransOverlay.default_delay);
        },

        dequeue: function() {
            var event = Labnotes.TransOverlay.next_event;
            Labnotes.TransOverlay.timer = null;
            if (event) {
                var overlay = Labnotes.TransOverlay.overlay;
                switch (event[0]) {
                case 'display':
                    var html = event[1][0];
                    if (typeof html == 'function')
                        html = html();
                    if (html) {
                        overlay.style.visibility = 'hidden';
                        var child = overlay.firstChild;
                        while (child) {
                            overlay.removeChild(child);
                            child = overlay.firstChild;
                        }
                    }
                    if (html && Labnotes.TransOverlay.setup_content(overlay, html)) {
                        var box = Labnotes.TransOverlay.box_from_element(event[1][1]);
                        overlay.style.left = ((box[0] + box[1] - overlay.offsetWidth) / 2) + "px";
                        overlay.style.top = box[3] + "px";
                        Labnotes.TransOverlay.safebox = [
                            overlay.offsetLeft < box[0] ? overlay.offsetLeft : box[0],
                            (overlay.offsetLeft + overlay.offsetWidth) > box[1] ? (overlay.offsetLeft + overlay.offsetWidth) : box[1],
                            box[2], overlay.offsetTop + overlay.offsetHeight
                        ];
                        overlay.style['opacity'] = 1;
                        overlay.style['-moz-opacity'] = 1;
                        overlay.style.visibility = 'visible';
                        overlay.style['filter'] = 'alpha(opacity=100)'; // Must come after visiblity=visible
                    }
                    break;
                case 'opacity':
                    var opacity = event[1];
                    if (opacity <= 0) {
                        overlay.style.visibility = 'hidden';
                        Labnotes.TransOverlay.safebox = null;
                    } else if (Labnotes.TransOverlay.safebox) {
                        overlay.style['opacity'] = opacity;
                        overlay.style['-moz-opacity'] = opacity;
                        overlay.style['filter'] = 'alpha(opacity=' + (opacity * 100) + ')';
                    }
                    break;
                }
            }
        },

        // Override this function to change how opacity is calculated.
        // distance -- mouse distance from the source element/overlay
        // Return opacity as a value between 0 (hide) and 1 (fully opaque).
        calc_opacity: function(distance) {
            var opacity = (10 - distance) / 10;
            return opacity > 0 ? opacity : 0;
        },

        // Override this function to change how the overlay looks visually.
        // This function is called when the overlay is displayed with new content,
        // while the overlay is still hidden. If it returns true, the overlay is made
        // visible.
        // html -- HTML content to display (string or XML)
        // overlay -- the overlay element
        // Returns true if the overlay is ready to be displayed.
        setup_content: function(overlay, html) {
            if (typeof html == 'string')
                overlay.innerHTML = html;
            else
                overlay.appendChild(html);
            return true;
        },

        // Call this function to display the overlay.
        // html -- HTML content to display (string, XML or function)
        // source -- Source element, required to position the overlay
        // delay -- Delay before popping up the overlay, in milliseconds (null/0 for no delay)
        display: function(html, source, delay) {
            if (delay) {
                if (Labnotes.TransOverlay.display_timer)
                    window.clearTimeout(Labnotes.TransOverlay.display_timer);
                Labnotes.TransOverlay.display_timer = window.setTimeout(function(){
                        Labnotes.TransOverlay.queue('display', [html, source], 0);
                    }, delay);
            } else
                Labnotes.TransOverlay.queue('display', [html, source]);
        },

        // Call this function to hide the overlay.
        hide: function(html) {
            Labnotes.TransOverlay.queue('opacity', 0);
        },

        // Call this function to cancel a previously scheduled call to display.
        // This function is used from onmouseout to cancel a previous call to display
        // from onmouseover, if the overlay has not been displayed yet.
        cancel: function(source) {
            if (Labnotes.TransOverlay.display_timer) {
                window.clearTimeout(Labnotes.TransOverlay.display_timer);
                Labnotes.TransOverlay.display_timer = null;
            }
        }

    };
// Initialize Labnotes.Overlay. Actual initialization takes place during onload.
Labnotes.TransOverlay.initialize();


// Add styling.
function addGlobalStyle(css) {
    var head = document.getElementsByTagName('head')[0];
    if (!head)
      return;
    var style = document.createElement('style');
    style.type = 'text/css';
    style.innerHTML = css;
    head.appendChild(style);
}


// TagsLinks.js
//
// TagsLinks makes tags more useful by turning each tag into links that point to
// different tagging services. Instead of linking to one Web site, tags now link
// to content on del.icio.us, images on Flickr, blogs on Technorati, and more.
//
// Requires behaviour.js (http://www.ripcord.co.nz/behaviour/) and
// TransOverlay (http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/TransOverlay).
//
// Version 0.6
// Copyright (C) 2005 Assaf Arkin http://labnotes.org
// License: Creative Commons Attribution-ShareAlike
// http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/TagsLinks

var Labnotes;
if (!Labnotes) Labnotes = {};
if (!Labnotes.TagsLinks)
    Labnotes.TagsLinks = {

        // The default list of services. You can customize this by adding
        // more services to the array, or calling TagsLinksAddService.
        services:  [
            ['Del.icio.us', 'http://del.icio.us/tag/', 'http://del.icio.us/favicon.ico'],
            ['Flickr', 'http://www.flickr.com/photos/tags/', 'http://www.flickr.com/favicon.ico'],
            ['Technorati', 'http://www.technorati.com/tag/', 'http://www.technorati.com/favicon.ico'],
            ['Upcoming.org', 'http://upcoming.org/tag/', 'http://upcoming.org/favicon.ico'],
            ['Connotea', 'http://www.connotea.org/tag/', 'http://www.connotea.org/favicon.ico'],
            ['Scuttle', 'http://scuttle.org/tags.php/', 'http://scuttle.org/favicon.ico'],
            ['BlogMarks', 'http://blogmarks.net/tag/', 'http://blogmarks.net/favicon.ico'],
            ['evdb', 'http://evdb.com/events/tags/', 'http://evdb.com/favicon.ico'],
            ['MyWeb 2.0', 'http://myweb2.search.yahoo.com/myweb?ei=UTF-8&dg=6&tag=', 'http://myweb2.search.yahoo.com/favicon.ico'],
            ['Odeo', 'http://odeo.com/tag/', 'http://odeo.com/favicon.ico'],
            ['Wikipedia', 'http://wikipedia.org/wiki/', 'http://wikipedia.org/favicon.ico']
        ],

        // Call this function to add a new tagging service.
        //
        // name  The service name
        // url   The base url. The tag is appended to this url to create
        //       the actual link. The url should end with a slash.
        // icon  Icon to display next to the link.
        add_service: function(name, url, icon) {
            if (name && url)
                Labnotes.TagsLinks.services[Labnotes.TagsLinks.services.length] = [name, url, icon];
        },

        // Called during initalization. This is where all the magic happens.
        // Arguments:
        //  icons     If true, icons appear next to the link
        initialize: function(icons) {
            // Alphabetize services.
            var services = Labnotes.TagsLinks.services;
            services.sort(function compare(a, b) {
                a = a[0].toLowerCase();
                b = b[0].toLowerCase();
                return (a < b) ? -1 : (a > b) ? 1 : 0;
            });
            // Register a behavior for relTag links.
            var myrules = {
            'a[rel~=tag]' : function(element) {
                if (!element.onmouseover && !element.onmouseout) {
                    element.onmouseover = function(){
                       if (element.href.match(/([^\/]+)\/?$/)) {
                            var tag = RegExp.$1;
                            if (tag) {
                                var html = '<div><strong>See more <em>'+decodeURI(tag).replace('+',' ')+'</em> from</strong>';
                                for (var i = 0; i < services.length ;++i) {
                                    html += '<div>';
                                    if (icons && services[i][2])
                                        html += '<img src="'+services[i][2]+'" />';
                                    html += '<a href="'+services[i][1]+tag+'">'+services[i][0]+'</a></div>';
                                }
                                html += '</div>';
                                Labnotes.TransOverlay.display(html, element, 500);
                            }
                        }
                    },
                    element.onmouseout = Labnotes.TransOverlay.cancel;
                }
            }
            };
            Behaviour.register(myrules);
        }
};

// Initialize everything.
// Change the first argument to true if you want icons next to each link.
if (Labnotes.TransOverlay && Behaviour)
    Labnotes.TagsLinks.initialize(false);

// Initialize everything.
// Change the first argument to true if you want icons next to each link.
addGlobalStyle(".labnotes_transoverlay{border:1px solid black;background:white;position:absolute;visibility:hidden;margin:20px020px0;padding:5px;font-family:Verdana,'Lucida Grande',Arial,Sans-Serif;font-size:10px;}");
}());
