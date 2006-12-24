# microformat helper plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


# Methods in this helper include:
# * #render_hfeed     -- Renders an hAtom feed element.
# * #render_hentry    -- Renders an hAtom feed entry element.
# * #hentry_title     -- Returns an hAtom feed entry title element.
# * #hentry_content   -- Returns an hAtom feed entry content element.
# * #hcard            -- Creates a simple hCard (name, url, photo).
# * Time#microformat  -- Turns a time into an +abbr+ element.
#
# Example:
#   <% render_hfeed do
#     posts.each do |post|
#       render_hentry "post-#{post.id}" do %>
#         <%= hentry_title post.title %>
#         <%= hentry_content post.content %>
#         <p>Published on <%= post.created_on.microformat :published %> by
#           <%= hcard :fn=>post.author, :url=>post.author_url, :class=>"author" %>
#         </p><%
#       end
#     end
#   end %>
#
# Notice that the example uses <% and not <%=. Using <% allows render_hfeed
# to wrap the output of the block inside a feed element. <%= will break.
module MicroformatHelper

  unless defined?(HATOM_CLASS)
    # Common classes used for hAtom.
    HATOM_CLASSES = %w{hfeed hentry hentry-title hentry-content author}

    # :call-seq:
    #   render_hfeed(options?) { ... }
    #
    # Called to render a feed. Creates an ordered list element with the class
    # +hfeed+ and the specified options and yields to the block.
    def render_hfeed(options = nil, &block)
      classes = "hfeed"
      if options
        classes << " #{options[:class]}" if options[:class]
        options = options.update(:class=>classes)
      else
        options = {:class=>classes}
      end
      concat(content_tag("ol", capture(&block), options), block.binding)
    end


    # :call-seq:
    #   render_hentry(id, options?) { ... }
    #
    # Called to render a feed entry. Creates a list item element with the
    # class +hentry+, specified ID attribute and options, and yields to the
    # block.
    def render_hentry(id, options = nil, &block)
      classes = "hentry"
      if options
        classes << " #{options[:class]}" if options[:class]
        options = options.update(:id=>id, :class=>classes)
      else
        options = {:id=>id, :class=>classes}
      end
      concat(content_tag("li", capture(&block), options), block.binding)
    end

    # :call-seq:
    #   hentry_title(title, options?)
    #   hentry_title(options?) { ... }
    #
    # Called to render the feed title element. The content is passed as
    # a string, or returned from the block.
    #
    # The title element is +h2+ by default. Use the +:level+ option to
    # pick a different header level. All other options are applied to that
    # element.
    def hentry_title(*args, &block)
      case arg = args.shift
        when Hash
          title = capture(&block)
          options = arg
        when nil
          title = capture(&block)
          options = args.shift
        else
          title = arg
          options = args.shift
      end
      classes = "entry-title"
      if options
        classes << " #{options[:class]}" if options[:class]
        options = options.update(:class=>classes)
      else
        options = {:class=>classes}
      end
      content_tag("h" << (options[:level] || 2).to_s, title, options)
    end

    # :call-seq:
    #   hentry_content(content, options?)
    #   hentry_content(options?) { ... }
    #
    # Called to render the feed content element. The content is passed as
    # a string, or returned from the block.
    #
    # The content element is +p+ by default. Use the +:tag+ option to
    # pick a different element name. All other options are applied to that
    # element.
    def hentry_content(*args, &block)
      case arg = args.shift
        when Hash
          content = capture(&block)
          options = arg
        when nil
          content = capture(&block)
          options = args.shift
        else
          content = arg
          options = args.shift
      end
      classes = "entry-content"
      if options
        classes << " #{options[:class]}" if options[:class]
        options = options.update(:class=>classes)
      else
        options = {:class=>classes}
      end
      content_tag(options.delete(:tag) || "p", content, options)
    end

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

  class ::Time

    unless defined?(microformat)
      # :call-seq:
      #   microformat(type, format?)
      #   microformat(type) { |time| ... }
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

  end


  module Assertions

    def assert_hdatetime(time, type, format = nil, &block)
      if format
        if format.is_a?(String)
          text = time.strftime(format)
        elsif format.respond_to?(:call)
          text = format.call(time)
        else
          raise ArgumentError, "Invalid format: expecting format string or block/proc"
        end
      elsif block
        text = block.call(time)
      else
        text = time.to_s
      end
      assert_select "abbr.#{type.to_s}[title=?]", time.xmlschema, text, &block
    end


    def assert_hfeed(&block)
      assert_select "ol.hfeed", true, "hAtom OL/feed element not matched", &block
    end

    def assert_hfeed_entry(id, &block)
      assert_select "li.hentry#?", id, true, "hAtom LI/entry element not matched", &block
    end

    def assert_hfeed_entry_title(title = nil, &block)
      tests = title ? {:text=>title} : true
      assert_select ".entry-title", tests, "hAtom title element not matched", &block
    end

    def assert_hfeed_entry_content(content = nil, &block)
      tests = content ? {:text=>content} : true
      assert_select ".entry-content", tests, "hAtom content element not matched", &block
    end

    def assert_hcard(values)
      classes = ".vcard.fn"
      classes << "." << values[:class].split(' ').join('.') if values[:class]
      fn = lambda do |element|
        if values[:fn]
          assert_select element, "*", {:text=>values[:fn]}, "FN value did not match"
        else
          if values[:given]
            assert_select element, "span.given-name", {:text=>values[:given]}, "Given name value did not match"
          end
          if values[:family]
            assert_select element, "span.family-name", {:text=>values[:family]}, "Family name value did not match"
          end
        end
        if photo = values[:photo]
          photo = photo[:src] if Hash === photo
          assert_select element, "img.photo[src=?]", photo, {:minimum=>1}, "Image did not match"
        end
      end
      if !values[:fn] and (values[:given] or values[:family])
        classes << ".n"
      end
      if url = values[:url]
        assert_select "a#{classes}.url[href=?]", url, true, "Link did not match" do |elements|
          elements.each { |element| fn.call(element) }
          yield elements if block_given?
        end
      else
        assert_select "span#{classes}", true, "SPAN element did not match" do |elements|
          elements.each { |element| fn.call(element) }
          yield elements if block_given?
        end
      end
    end

  end

 end
