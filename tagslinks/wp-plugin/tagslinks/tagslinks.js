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
