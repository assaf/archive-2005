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
