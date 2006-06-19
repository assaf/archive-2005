# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require File.join(File.dirname(__FILE__), "reader")
require File.join(File.dirname(__FILE__), "html_selector")


module Scraper


    class Base

        unless const_defined? :READER_OPTIONS
            READER_OPTIONS = [:last_modified, :etag, :redirect_limit, :user_agent]
            INHERITABLE_OPTIONS = [:redirect_limit, :root_element, :tidy_options]
        end


        # Used by extractors to access the current element (also passed as
        # argument).
        attr_reader :element

        # The URL of the document being processed. Passed in the initializer,
        # but may change during scraping, e.g. if the server redirects us.
        attr_reader :url

        # The URL of the document being processed. The URL passed in the
        # initializer, ignoring any redirection.
        attr_reader :original_url

        # Last modified and Etag headers. Passed in the initialized from
        # a previous read of the page. The response headers are available
        # after calling #scrape.
        attr_reader :last_modified, :etag

        # The encoding of the document being processed.
        attr_reader :encoding

        # Set to true if any extractor returned true.
        attr_accessor :extracted


        # Create a new scraper.
        #
        # The first argument provides the input for scraping.
        # It may be one of the following:
        # * +URI+ -- A URL from which to retrieve the HTML page.
        #   Must be HTTP or HTTPs.
        # * +String+ -- The HTML content.
        # * +HTML::Node+ -- An HTML node.
        #
        # The following options are supported for reading HTML pages:
        # * :last_modified -- Last modified header (for cache control).
        # * :etag -- ETag header (for cache control)
        # * :redirect_limit -- Number of redirects allowed (default is 3).
        # * :user_agent -- The User-Agent header to send.
        #
        # The following options are supported for parsing the HTML:
        # * :root_element -- The root element to use, see #root_element.
        # * :tidy_options -- Options passed to Tidy, see #tidy_options.
        #
        # For example:
        #   url = URI.parse("http://example.com")
        #   scraper = MyScraper.new(url, :root_element=>"html")
        #   result = scraper.scrape
        # Or:
        #   result = MyScraper.scrape(url, :root_element=>"html")
        def initialize(what, options = nil)
            case what
            when URI: @url = @original_url = what
            when HTML::Node: @document = what
            when String: @html = what
            else raise ArgumentError, "Can only scrape URI, String or HTML::Node"
            end
            @options = options || {}
        end


        # :call-seq:
        #   process(selector, extractor)
        #   process(selector) { |element| ... }
        #
        # Defines a processing rule. A processing rule consists of a selector
        # that identifies matching elements, and an extractor that operates
        # on these elements.
        #
        # == Selector
        #
        # The first argument is a selector. It selects elements from the
        # document that are potential candidates for extraction. Each selected
        # element is passed to the extractor.
        #
        # The +selector+ argument may be a string, an array (string with
        # arguments) or HTML::Selector. It may also be an object that
        # responds to the method +match+, see HTML::Selector for the
        # expected behavior of this method.
        #
        # For performance reasons, the selector must not attempt to recurse
        # over child nodes unless necessary (e.g. for selecting descendants).
        # The scraper will iterate over all elements in the document body.
        # As such, it may return +nil+ if no match is found, a single element,
        # or an array of elements.
        #
        # == Extractor
        #
        # The second argument is an extractor. It operates on the selected
        # element and extracts a value from it, and stores it in the scraper.
        # It can use the scraper object to maintain state.
        #
        # The extractor is a block evaluated in the context of the scraper.
        # It can access the selected element as an argument, or by calling
        # #element.
        #
        # The extractor returns +true+ if the element was processed and
        # should not be presented to any other extractor (including any
        # of its child elementS).
        #
        # Alternatively, it can skip selected elements by calling #skip.
        #
        # Note: When using a block, the last statement if the response.
        # Do not use +return+, use +next+ if you want to return a value
        # before the last statement.
        #
        # == Examples
        #
        #   process ".post" do |elem|
        #     posts << Post.new(elem)
        #     true
        #   end
        #
        #   process ["#?", /post-\d+/] do
        #     posts << Post.new(element)
        #     skip(element)
        #   end
        def self.process(*selector, &block)
            raise ArgumentError, "Missing selector" if selector.empty?
            unless block
                if selector.last.is_a?(Proc)
                    block = selector.pop
                else
                    raise ArgumentError, "Missing extractor"
                end
            end
            if selector[0].is_a?(String)
                selector = HTML::Selector.new(*selector)
            else
                raise ArgumentError, "Selector must respond to select() method" unless
                    selector.respond_to?(:select)
                selector = selector[0]
            end
            define_method :__extractor, block
            rules << [selector, instance_method(:__extractor)]
            remove_method :__extractor
            return self
        end


        # :call-seq:
        #   selector(symbol, selector, values?)
        #   selector(symbol, selector, values?) { |elements| ... }
        #
        # Create a selector method.
        #
        # A selector method is called with an element and returns an array
        # of elements that match the selector beginning with the root
        # element itself. If no match is found, it returns an empty array.
        #
        # If the selector is defined with a block, the selected elements
        # are passed to the block and the result of the block is returned.
        #
        # The +selector+ argument may be a string, with or without arguments,
        # or HTML::Selector. It may also be an object that responds to the
        # method +select+, see HTML::Selector for the expected behavior of
        # this method.
        #
        # For example:
        #   selector :divs, "div" { |elems| elems.reverse }
        # Calling divs(element) will return all elements of type +div+
        # in reverse order.
        #
        # Note: When using a block, the last statement if the response.
        # Do not use +return+, use +next+ if you want to return a value
        # before the last statement.
        def self.selector(symbol, *selector, &block)
            raise ArgumentError, "Missing selector" if selector.empty?
            if selector[0].is_a?(String)
                selector = HTML::Selector.new(*selector)
            else
                raise ArgumentError, "Selector must respond to select() method" unless
                    selector.respond_to?(:select)
                selector = selector[0]
            end
            symbol = symbol.to_sym
            if block
                define_method symbol do |element|
                    nodes = selector.select(element)
                    return block.call(nodes)
                end
            else
                define_method symbol do |element|
                    return selector.select(element)
                end
            end
        end


        def self.extractor(map)
            extracts = []
            map.each_pair do |target, source|
                source = extract_value_from(source)
                target = extract_value_to(target)
                define_method :__extractor do |element|
                    value = source.call(element)
                    target.call(self, value) if value
                end
                extracts << instance_method(:__extractor)
                remove_method :__extractor
            end
            lambda do |element|
                extracts.each do |extract|
                    extract.bind(self).call(element)
                end
                true
            end
        end


        # Sets the root element.
        #
        # Each document has a root element. If the root element is +nil+,
        # the scraper will process that element and all its child elements.
        # You can pick a different element, e.g. +body+ to process the
        # body of the HTML document and ignore the header.
        #
        # The default root element is +body+.
        #
        # This method sets the root element for the class. Otherwise,
        # inherit the root element specified for the parent class.
        # To set the root element for the object, use the option
        # +:root_element+ when creating a new object.
        def self.root_element(name)
            @root_element = name ? name.to_s : nil
        end

        root_element "body"


        # Options to pass to Tidy.
        #
        # This method sets the tidy options for the class. Otherwise,
        # inherit the tidy options of the parent class. To set the
        # tidy options for the object, use the option +:tidy_options+
        # when creating a new object.
        def self.tidy_options(options)
            @tidy_options = options
        end


        def self.scrape(what, options = nil)
            scraper = self.new(what, options);
            return scraper.scrape
        end


        def scrape()
            # Process the body one node at a time, depth first.
            case document
            when Array
                stack = @document
            when HTML::Node
                root_name = @options.has_key?(:root_element) ?
                    @options[:root_element] : option(:root_element)
                stack = [@document.find(:tag=>root_name)]
            else
                return nil
            end
            # @skip stores all the elements we want to skip (see #skip).
            # rules stores all the rules we want to process with this
            # scraper, based on the class definition.
            @skip = []
            rules = self.class.rules
            while node = stack.pop
                skip_this = false
                # Only match nodes that are elements, ignore text nodes.
                # Also ignore any element that was added to the skip list,
                # and remove it from the list.
                # Note: equal? is faster than == for nodes.
                unless node.tag?
                    if children = node.children
                        stack += children.reverse
                    end
                    next
                end
                @skip.delete_if { |skipped| skip_this = true if skipped.equal?(node) }
                next if skip_this

                # Run through all the elements until we process the element
                # or run out of rules. Watch for skip_this=true which indicates
                # we processed the element. Also watch the skip list, since we
                # may have processed this element before as a descendant.
                rules.each do |selector, extractor|
                    break if skip_this
                    # Selected is nil, element or array of elements.
                    # We'll turn it into an array and process one
                    # selected element at a time.
                    if selected = selector.match(node)
                        selected = [selected] unless selected.is_a?(Array)
                        selected.each do |element|
                            # Do not process elements we already skipped
                            # (see above).
                            @skip.delete_if { |skipped| skip_this = true if skipped.equal?(element) }
                            next if skip_this
                            # Call the extractor method with this element.
                            # If it returns true, skip this element from
                            # further processing.
                            @element = element
                            if extractor.bind(self).call(element)
                                @extracted = true
                                if element.equal?(node)
                                    skip_this = true
                                else
                                    @skip << element
                                end
                            end
                        end
                    end
                end

                # If we did not skip the element, we're going to process its
                # children. Reverse order since we're popping from the stack.
                if !skip_this && children = node.children
                    stack += children.reverse
                end
            end
            @skip = @element = nil
            return result
        end


        # The document being processes.
        def document
            unless @document
                if @url
                    # Attempt to read page. May raise HTTPError.
                    options = READER_OPTIONS.inject({}) { |h,k| h[k] = @options[k] ; h }
                    options[:redirect_limit] ||= option(:redirect_limit)
                    if page = Reader.read_page(@url, @options)
                        @url = page[:url] if page[:url]
                        @last_modified, @etag = page[:last_modified], page[:etag]
                        @encoding = page[:encoding]
                        @html = page[:content]
                    end
                end
                if @html
                    # Parse the page. May raise HTMLParseError.
                    parsed = Reader.parse_page(@html, @encoding,
                        @options.has_key?(:tidy_options) ? @options[:tidy_options] : option(:tidy_options))
                    # Store HTML document and actual encoding.
                    @document, @encoding = parsed[:document], parsed[:encoding]
                end
            end
            @document
        end


        # :call-seq:
        #   skip() => true
        #   skip(element) => true
        #   skip([element ...]) => true
        #
        # Skips processing of the specified element(s).
        #
        # If called with an array, skips processing all elements
        # from that array. If called with a single element, skips
        # processing that element. If called with +nil+, skips
        # processing the current element (see #element).
        def skip(elements = nil)
            case elements
            when Array: @skip += elements
            when nil: @skip << element
            else @skip << elements
            end
            # Calling skip(element) as the last statement is
            # redundant by design.
            return true
        end


        def self.text(element)
            text = ""
            stack = element.children
            while node = stack.pop
                if node.tag?
                    stack += node.children
                else
                    text << node.content
                end
            end
            return text
        end

        def self.node(element)
            element
        end


        # Returns the result, nil if nothing was extracted.
        #
        # This method is called by #scrape after running all the
        # rules. You can also call it directly.
        #
        # The default implementation returns +self+ if anything
        # was extracted, +nil+ otherwise. You can override it to
        # create and return a different object, or perform some
        # post-scraping work, 
        def result
            @extracted ? self : nil
        end


protected

        def self.extract_value_from(source)
            case source
            when Array
                array = source.collect { |i| extract_value_from(i) }
                lambda do |element|
                    result = nil
                    array.each do |proc|
                        break if result = proc.call(element)
                    end
                    result
                end
            when Hash
                hash = source.inject({}) { |h,p| h[p[0]] = extract_value_from(p[1]) ; h }
                lambda do |element|
                    result = {}
                    hash.each_pair do |source, target|
                        value = target.call(element)
                        result[source] = value if value
                    end
                    result
                end
            when Class
                while supercls = source.superclass
                    break if supercls == Scraper::Base
                end
                raise ArgumentError, "Class must be a scraper" unless
                    supercls
                lambda { |element| source.new(element).scrape }
            when Symbol
                method = method(source) rescue
                    raise(ArgumentError, "No method #{source} in #{self.class}")
                lambda { |element| method.call(element) }
            when /^[\w\-:]+$/
                lambda { |element| element if element.name == source }
            when /^@[\w\-:]+$/
                attr_name = source[1..-1]
                lambda { |element| element.attributes[attr_name] }
            when /^[\w\-:]+@[\w\-:]+$/
                tag_name, attr_name = source.match(/^([\w\-:]+)@([\w\-:]+)$/)[1..2]
                lambda do |element|
                    element.attributes[attr_name] if
                        element.name == tag_name
                end
            else
                raise ArgumentError, "Invalid extractor #{source.to_s}"
            end
        end


        def self.extract_value_to(target)
            target = target.to_s
            if target[-2..-1] == "[]"
                symbol = "@#{target[0...-2]}".to_sym
                lambda do |object, value|
                    array = object.instance_variable_get(symbol)
                    object.instance_variable_set(symbol, array = []) unless array
                    array << value
                end
            else
                symbol = "@#{target}".to_sym
                lambda { |object, value| object.instance_variable_set(symbol, value) }
            end
        end


        # Returns an array of all rules associated with this scraper.
        # Each rule is a pair consisting of a selector and an extractor.
        #
        # The selector responds to +call+ and takes a single argument (element)
        # returning an array of nodes or nil.
        #
        # The extractor is a symbol corresponding to an instance method of the
        # scraper. The method takes a single element as argument and returns
        # true if that element was processed, false otherwise.
        def self.rules()
            rules = self.instance_variable_get(:@rules)
            self.instance_variable_set(:@rules, rules = []) unless rules
            return rules
        end


        def self.inherited(child)
            super
            INHERITABLE_OPTIONS.each do |name|
                sym = "@#{name}".to_sym
                child.instance_variable_set(sym, instance_variable_get(sym))
            end
        end


        def option(name)
            self.class.instance_variable_get("@#{name}")
        end

    end

end
