# microformat helper plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


# Example:
#   <% hrender_feed do
#     posts.each do |post|
#       hrender_entry "post-#{post.id}" do %>
#         <%= post.content %>
#         <p>Published on <%= post.created_on.microformat :published %> by
#           <%= hcard :fn=>post.author, :url=>post.author_url, :class=>"author" %>
#         </p><%
#       end
#     end
#   end %>
module MicroformatHelper

  module HAtom # :nodoc:

    DATETIME_TYPES = [:published, :updated]

    # :call-seq:
    #   render_hfeed(options?) { ... }
    #
    # Called to render a feed. Creates an ordered list element with the class
    # +hfeed+ and the specified options and yields to the block.
    #
    # Use with rhtml like this:
    #   <% hrender_feed do
    #     posts.each do |post|
    #       hrender_entry "post-#{post.id}" do %>
    #         <%= post.content %>
    #       end
    #     end
    #   end %>
    #
    # Notice that the example uses <% and not <%=. Using <% allows render_hfeed
    # to wrap the output of the block inside a feed element. <%= will break.
    def render_hfeed(options = nil, &block)
      options ||= {}
      classes = options.delete(:class)
      options[:class] = "hfeed"
      options[:class] << " #{classes}" if classes 

      Binding.of_caller do |binding|
        concat content_tag("ol", capture(&block), options), binding
      end
    end


    # :call-seq:
    #   render_hentry(id, options?) { ... }
    #
    # Called to render a feed entry. Creates a list item element with the
    # class +hentry+, specified ID attribute and options, and yields to the
    # block.
    #
    # For usage example, see #render_hfeed.
    def render_hentry(id, options = nil, &block)
      options ||= {}
      classes = options.delete(:class)
      options[:class] = "hentry"
      options[:class] << " #{classes}" if classes 
      options[:id] = id

      Binding.of_caller do |binding|
        concat content_tag("li", capture(&block), options), binding
      end
    end

  end


  module DateTime # :nodoc:

    # :call-seq:
    #   time.microformat(type, format?)
    #   time.microformat(type) { |time| ... }
    #
    # Called to microformat a #Time in the form of an +abbr+ element.
    #
    # The first argument specifies the data type, e.g. :published,
    # :updated, :dtstart, :dtend, etc. This gets translated to a class.
    #
    # The human readable date/time is formatted using Time#to_s, however
    # you can also pass a format string (see Time#strftime) or a block.
    #
    # For example:
    #   Time.now.microformat(:published, "%Y %m %d")
    def microformat(type, format = nil, &block)
      if format
        if format.is_a?(String)
          text = self.strftime(format)
        elsif format.respond_to?(:call)
          text = format.call(self)
        else
          raise ArgumentError, "Invalid format: expecting format string or block/proc"
        end
      elsif block
        text = block.call(self)
      else
        text = self.to_s
      end
      "<abbr class='#{type.to_s}' title='#{self.xmlschema}'>#{text}</abbr>"
    end

  end


  module HCard # :nodoc:

    # :call-seq:
    #   hcard(values)
    #
    # Called to create a simple hcard for a name with optional URL and photo.
    #
    # Supported values are:
    # * +:fn+     -- Formal name.
    # * +:given+  -- Given name. Can be used with family name, but not with fn.
    # * +:family+ -- Family name. Can be used with given name, but not with fn.
    # * +:photo+  -- A URL to a photo, or a hash of HTML options to pass to the
    #                tag function. If used, comes before the name.
    # * +:url+    -- A URL link. Can be a string or any of the options supported
    #                by #link_to.
    # * +:class+  -- Additional class names to use on the wrapping element.
    # * +:html+   -- Additional HTML options to pass to the wrapping element.
    #
    # Examples:
    #   hcard :given=>"Assaf", :family=>"Arkin"
    #   hcard :fn=>"Assaf", :photo=>"/profile.jpg", :url=>"http://labnotes.org"
    #   hcard :fn=>"Assaf", :url=>"http://labnotes.org", :class=>"author"
    def hcard(values)
      # Support passing additional class names (e.g. author).
      html_options = (values[:html] || {})
      if classes = values[:class]
        classes << " vcard fn"
      else
        classes = "vcard fn"
      end
      # Figure out the name. Either FN or combination of family, given.
      unless fn = values[:fn]
        if given = values[:given]
          fn = content_tag("span", given, :class=>"given-name")
        end
        if family = values[:family]
          fn = "" unless fn
          fn = content_tag("span", family, :class=>"family-name")
        end
        classes << " n" if fn
      end
      # Prepend with image if specified. 
      if photo = values[:photo]
        if Hash === photo
          photo_class = "photo"
          photo_class << " #{photo[:class]}" if photo[:class]
          photo = photo.update(:class=>photo_class)
        else
          photo = {:src=>photo, :class=>"photo"}
        end
        fn = tag("img", photo) << " #{fn}"
      end
      # Create link or span. Support passing url_for options.
      if url = values[:url]
        link_to(fn, url, html_options.update(:class=>"#{classes} url"))
      else
        content_tag("span", fn, html_options.update(:class=>classes))
      end
    end

  end


  Time.send :include, DateTime
  [HAtom, HCard].each { |m| include m }

 end
