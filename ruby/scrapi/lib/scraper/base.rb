# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require File.join(File.dirname(__FILE__), "reader")


module Scraper

    class Base


        # Information about the HTML page scraped. A structure with the following
        # attributes:
        # * <tt>url</tt> -- The URL of the document being scraped. Passed in
        #   the constructor but may have changed if the page was redirected.
        # * <tt>original_url</tt> -- The original URL of the document being
        #   scraped as passed in the constructor.
        # * <tt>encoding</tt> -- The encoding of the document.
        # * <tt>last_modified</tt> -- Value of the Last-Modified header returned
        #   from the server.
        # * <tt>etag</tt> -- Value of the Etag header returned from the server.
        PageInfo = Struct.new(:url, :original_url, :encoding, :last_modified, :etag)


        class << self

            # :call-seq:
            #   process(symbol?, selector, values?, extractor)
            #   process(symbol?, selector, values?) { |element| ... }
            #
            # Defines a processing rule. A processing rule consists of a selector
            # that matches element, and an extractor that does something interesting
            # with their value.
            #
            # == Symbol
            #
            # Rules are processed in the order in which they are defined. Use #rules
            # if you need to change the order of processing.
            #
            # Rules can be named or anonymous. If the first argument is a symbol,
            # it is used as the rule name. You can use the rule name to position,
            # remove or replace it.
            #
            # == Selector
            #
            # The first argument is a selector. It selects elements from the document
            # that are potential candidates for extraction. Each selected element is
            # passed to the extractor.
            #
            # The +selector+ argument may be a string, an HTML::Selector object or
            # any object that responds to the +select+ method. Passing an Array
            # (responds to +select+) will not do anything useful.
            #
            # String selectors support value substitution, replacing question marks
            # (?) in the selector expression with values from the method arguments.
            # See HTML::Selector for more information.
            #
            # == Extractor
            #
            # The last argument or block is the extractor. The extractor does
            # something interested with the selected element, typically assigns
            # it to an instance variable of the scraper.
            #
            # Since the extractor is called on the scraper, it can also use the
            # scraper to maintain state, e.g. this extractor counts how many
            # +div+ elements appear in the document:
            #   process "div" { |element| @count += 1 }
            #
            # The extractor returns +true+ if the element was processed and
            # should not be passed to any other extractor (including any child
            # elements).
            #
            # The default implementation of #result returns +self+ only if at
            # least one extractor returned +true+. However, you can override
            # #result and use extractors that return +false+.
            #
            # A block extractor is called with a single element. It can also
            # access the current element using the +element+ method.
            #
            # You can also use the #extractor method to create extractors that
            # assign elements, attributes and text values to instance variables,
            # or pass a +Hash+ as the last argument to #process. See #extractor
            # for more information.
            #
            # When using a block, the last statement is the response. Do not use
            # +return+, use +next+ if you want to return a value before the last
            # statement. +return+ does not do what you expect it to.
            #
            # == Example
            #
            # class ScrapePosts < Scraper::Base
            #   # Select the title of a post
            #   selector :select_title, "h2"
            #
            #   # Select the body of a post
            #   selector :select_body, ".body"
            #
            #   # All elements with class name post.
            #   process ".post" do |element|
            #     title = select_title(element)
            #     body = select_body(element)
            #     @posts << Post.new(title, body)
            #     true
            #   end
            #
            #   attr_reader :posts
            # end
            #
            # posts = ScrapePosts.scrape(html).posts
            def process(*selector, &block)
                # First argument may be the rule name.
                name = selector.shift if
                    selector.first.is_a?(Symbol)
                # Extractor is either a block, or the last argument.
                unless block
                    if selector.last.is_a?(Proc)
                        block = selector.pop
                    elsif selector.last.is_a?(Hash)
                        block = extractor(selector.pop)
                    else
                        raise ArgumentError, "Missing extractor: the last argument tells us what to extract"
                    end
                end
                # And if we think the extractor is the last argument,
                # it's certainly not the selector.
                raise ArgumentError,
                    "Missing selector: the first argument tells us what to select" if
                    selector.empty?
                if selector[0].is_a?(String)
                    selector = HTML::Selector.new(*selector)
                else
                    raise ArgumentError, "Selector must respond to select() method" unless
                        selector.respond_to?(:select)
                    selector = selector[0]
                end
                # Create a method for fast evaluation.
                define_method :__extractor, block
                method = instance_method(:__extractor)
                remove_method :__extractor
                # Decide where to put the rule.
                pos = rules.length
                if name
                    if find = rules.find {|rule| rule[2] == name }
                        find[0] = selector
                        find[1] = method
                    else
                        rules << [selector, method, name]
                    end
                else
                    rules << [selector, method, name]
                end
            end


            # :call-seq:
            #   selector(symbol, selector, values?)
            #   selector(symbol, selector, values?) { |elements| ... }
            #
            # Create a selector method. You can call a selector method directly
            # to select elements.
            #
            # For example, define a selector:
            #   selector :five_divs, "div" { |elems| elems[0..4] }
            # And call it to retrieve the first five +div+ elements:
            #   divs = five_divs(element)
            #
            # Call a selector method with an element and it returns an array of
            # elements that match the selector, beginning with the element argument
            # itself. It returns an empty array if nothing matches.
            #
            # If the selector is defined with a block, all selected elements are
            # passed to the block and the result of the block is returned.
            #
            # The +selector+ argument may be a string, an HTML::Selector object or
            # any object that responds to the +select+ method. Passing an Array
            # (responds to +select+) will not do anything useful.
            #
            # String selectors support value substitution, replacing question marks
            # (?) in the selector expression with values from the method arguments.
            # See HTML::Selector for more information.
            #
            # When using a block, the last statement is the response. Do not use
            # +return+, use +next+ if you want to return a value before the last
            # statement. +return+ does not do what you expect it to.
            def selector(symbol, *selector, &block)
                raise ArgumentError,
                    "Missing selector: the first argument tells us what to select" if
                    selector.empty?
                if selector[0].is_a?(String)
                    selector = HTML::Selector.new(*selector)
                else
                    raise ArgumentError, "Selector must respond to select() method" unless
                        selector.respond_to?(:select)
                    selector = selector[0]
                end
                if block
                    define_method symbol do |element|
                        selected = selector.select(element)
                        return block.call(selected) unless selected.empty?
                    end
                else
                    define_method symbol do |element|
                        return selector.select(element)
                    end
                end
            end


            # Creates an extractor that will extract values from the selected
            # element and place them in instance variables of the scraper.
            # You can pass the result to #process.
            #
            # == Example
            #
            # This example processes a document looking for an element with the
            # class name +article+. It extracts the attribute +id+ and stores it
            # in the instance variable +@id+. It extracts the article node itself
            # and puts it in the instance variable +@article+.
            #
            #   class ArticleScraper < Scraper::Base
            #     process ".article", extractor(:id=>"@id", :article=>:node)
            #     attr_reader :id, :node
            #   end
            #   result = ArticleScraper.scrape(html)
            #   puts result.id
            #   puts result.article
            #
            # == Sources
            #
            # Extractors operate on the selected element, and can extract the
            # following values:
            # * <tt>"elem_name"</tt> -- Extracts the element itself if it matches the
            #   element name (e.g. "h2" will extract only level 2 header elements).
            # * <tt>"attr_name"</tt> -- Extracts the attribute value from the element
            #   if specified (e.g. "@id" will extract the id attribute).
            # * <tt>"elem_name@attr_name"</tt> -- Extracts the attribute value from
            #   the element if specified, but only if the element has the specified
            #   name (e.g. "h2@id").
            # * <tt>:node</tt> -- Extracts the node itself.
            # * <tt>:text</tt> -- Extracts the text value of the node.
            # * <tt>Scraper</tt> -- Using this class creates a scraper to process
            #   the current element and extract the result. This can be used for
            #   handling complex structure.
            #
            # If you use an array of sources, the first source that matches anything
            # is used. For example, <tt>["attr@title", :text]</tt> extracts the value
            # of the +title+ attribute if the element is +abbr+, otherwise the text
            # value of the element.
            #
            # If you use a hash, you can extract multiple values at the same time.
            # For example, <tt>{:id=>"@id", :class=>"@class"}</tt> extracts the
            # +id+ and +class+ attribute values.
            #
            # :node and :text are special cases of symbols. You can pass any symbol
            # that matches a class method and that class method will be called to
            # extract a value from the selected element. You can also pass a Proc
            # or Method directly.
            #
            # == Targets
            #
            # Extractors assign the extracted value to an instance variable of the
            # scraper. The instance variable contains the last value extracted.
            #
            # If you want to extract multiple values into the same variables,
            # append <tt>[]</tt> to the variable name. For example:
            #   process "*", "id[]"=>"@id"
            # finds all the id attributes in the document and adds them to the
            # array variable +id+.
            def extractor(map)
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


            # Scrapes the document and returns the result.
            #
            # The first argument provides the input document. It can be one of:
            # * <tt>URI</tt> -- Retrieve an HTML page from this URL and scrape it.
            # * <tt>String</tt> -- The HTML page as a string.
            # * <tt>HTML::Node</tt> -- An HTML node, can be a document or element.
            #
            # You can specify options for the scraper class, or override these
            # by passing options in the second argument. Some options only make
            # sense in the constructor.
            #
            # The following options are supported for reading HTML pages:
            # * <tt>:last_modified</tt> -- Last-Modified header used for caching.
            # * <tt>:etag</tt> -- ETag header used for caching.
            # * <tt>:redirect_limit</tt> -- Limits number of redirects to follow.
            # * <tt>:user_agent</tt> -- Value for User-Agent header.
            # * <tt>:timeout</tt> -- HTTP open connection/read timeouts (in second).
            #
            # The following options are supported for parsing the HTML:
            # * <tt>:root_element</tt> -- The root element to scrape, see
            #   also #root_elements.
            # * <tt>:tidy_options</tt> -- Options to pass to Tidy. Options are
            #   required in order to use Tidy, see #tidy_options for details.
            #
            # The result is returned by calling the #result method. The default
            # implementation returns +self+ if any extractor returned true,
            # +nil+ otherwise.
            #
            # For example:
            #   result = MyScraper.scrape(url, :root_element=>"body")
            #
            # The method may raise any number of exceptions. HTTPError indicates
            # it failed to retrieve the HTML page, and HTMLParseError that it failed
            # to parse the page. Other exceptions come from extractors and the
            # #result method.
            def scrape(source, options = nil)
                scraper = self.new(source, options);
                return scraper.scrape
            end


            # Returns the text of the element.
            #
            # You can use this method from an extractor, e.g.:
            #   process "title", :title=>:text
            def text(element)
                text = ""
                stack = element.children
                while node = stack.pop
                    if node.tag?
                        stack += node.children.reverse
                    else
                        text << node.content
                    end
                end
                return text
            end


            # Returns the element itself.
            #
            # You can use this method from an extractor, e.g.:
            #   process "h1", :header=>:node
            def node(element)
                element
            end


            # Options to pass to Tidy.
            #
            # You must provide options in order to use Tidy, otherwise it defaults
            # to using the HTMLParser. If you don't have any options besides the
            # default, pass an empty Hash.
            #
            # This method sets the option for the class. Classes inherit options
            # from their parents. You can also pass options to the scraper object
            # itself using the +:tidy_options+ option.
            def tidy_options(options)
                options[:tidy_options] = options
            end


            # The root element to scrape.
            #
            # The root element for an HTML document is +html+. However, if you want
            # to scrape only the header or body, you can set the root_element to
            # +head+ or +body+.
            #
            # This method sets the root element for the class. Classes inherit
            # this option from their parents. You can also pass a root element
            # to the scraper object itself using the +:root_element+ option.
            def root_element(name)
                options[:root_element] = name ? name.to_s : nil
            end


            # Returns the options for this class.
            def options()
                @options ||= {}
            end


            # Returns an array of rules defined for this class. You can use this
            # array to change the order of rules.
            def rules()
                @rules ||= []
            end


        private

            # Returns a Proc that will extract a value from an element.
            #
            # The +source+ argument specifies which value to extract.
            # See #extractor for more details.
            #
            # The Proc is called with an element and returns a value
            # or +nil+.
            def extract_value_from(source)
                case source
                when Array
                    # For an array, each item is itself a source argument.
                    # We stop at the first value we're able to extract.
                    array = source.collect { |i| extract_value_from(i) }
                    return lambda do |element|
                        result = nil
                        array.each { |proc| break if result = proc.call(element) }
                        result
                    end
                when Hash
                    # For a hash, each pair is a symbol and source argument.
                    # We extract all the values and set them in the hash.
                    hash = source.inject({}) { |h,p| h[p[0]] = extract_value_from(p[1]) ; h }
                    return lambda do |element|
                        result = {}
                        hash.each_pair do |source, target|
                            if value = target.call(element)
                                result[source] = value
                            end
                        end
                        result unless result.empty?
                    end
                when Class
                    # A class is a scraper we run on the extracted element.
                    # It must extend Scraper::Base.
                    while supercls = source.superclass
                        break if supercls == Scraper::Base
                    end
                    raise ArgumentError,
                        "Class must be a scraper that extends Scraper::Base" unless
                        supercls
                    return lambda { |element| source.new(element).scrape }
                when Symbol
                    # A symbol is a method we call. We pass it the element
                    # and it returns the extracted value. It must be a class method.
                    method = method(source) rescue
                        raise(ArgumentError, "No method #{source} in #{self.class}")
                    return lambda { |element| method.call(element) }
                when Proc, Method
                    # Self evident.
                    raise ArgumentError,
                        "Proc or Method must take one argument (an element)" if
                        source.arity == 0
                    return source
                when /^[\w\-:]+$/
                    # An element name. Return the element if the name matches.
                    return lambda { |element| element if element.name == source }
                when /^@[\w\-:]+$/
                    # An attribute name. Return its value if the attribute is specified.
                    attr_name = source[1..-1]
                    return lambda { |element| element.attributes[attr_name] }
                when /^[\w\-:]+@[\w\-:]+$/
                    # An element with attribute name. Return the attribute value if
                    # the attribute is specified, and the element name matches.
                    tag_name, attr_name = source.match(/^([\w\-:]+)@([\w\-:]+)$/)[1..2]
                    return lambda do |element|
                        element.attributes[attr_name] if
                            element.name == tag_name
                    end
                else
                    # Anything else and pianos fall from the sky.
                    raise ArgumentError, "Invalid extractor #{source.to_s}"
                end
            end


            # Returns a Proc that will set the extract value in the object.
            #
            # The +target+ argument identifies an instance variable. It may
            # be the name of a variable, or the name of a variable prefixed
            # with [] to denote an array.
            #
            # The Proc is called with two arguments: the object to set the
            # value in, and the value.
            def extract_value_to(target)
                target = target.to_s
                if target[-2..-1] == "[]"
                    # Target is an array, append extracted values there.
                    symbol = "@#{target[0...-2]}".to_sym
                    return lambda do |object, value|
                        array = object.instance_variable_get(symbol)
                        object.instance_variable_set(symbol, array = []) unless array
                        array << value
                    end
                else
                    # Target is an instance variable, just set the new
                    # value. Don't worry about overriding a previous value.
                    symbol = "@#{target}".to_sym
                    return lambda { |object, value| object.instance_variable_set(symbol, value) }
                end
            end


            def inherited(child)
                super
                # Duplicate options and rules to any inherited class.
                child.options.merge options
                child.rules.concat rules
            end

        end


        unless const_defined? :READER_OPTIONS
            READER_OPTIONS = [:last_modified, :etag, :redirect_limit, :user_agent, :timeout]
        end


        # Used by extractors to access the current element (also passed as
        # argument).
        attr_reader :element


        # Set to true when the first extractor returns true.
        attr_accessor :extracted


        # Information about the HTML page scraped. See PageInfo.
        attr_accessor :page_info


        # Returns the options for this object.
        attr_accessor :options


        # Create a new scraper instance.
        #
        # The argument +source+ is a URL, string containing HTML, or HTML::Node.
        # The optional argument +options+ are options passed to the scraper.
        # See Base#scrape for more details.
        #
        # For example:
        #   # The page we want to scrape
        #   url = URI.parse("http://example.com")
        #   # Skip the header
        #   scraper = MyScraper.new(url, :root_element=>"body")
        #   result = scraper.scrape
        def initialize(source, options = nil)
            @page_info = PageInfo[]
            @options = options || {}
            case source
            when URI
                @source = source
            when String, HTML::Node
                @source = source
                # TODO: document and test case these two.
                @page_info.url = @page_info.original_url = @options[:url]
                @page_info.encoding = @options[:encoding]
            else
                raise ArgumentError, "Can only scrape URI, String or HTML::Node"
            end
        end


        # Scrapes the document and returns the result.
        #
        # If the scraper was created with a URL, retrieve the page and parse it.
        # If the scraper was created with a string, parse the page.
        #
        # The result is returned by calling the #result method. The default
        # implementation returns +self+ if any extractor returned true,
        # +nil+ otherwise.
        #
        # The method may raise any number of exceptions. HTTPError indicates
        # it failed to retrieve the HTML page, and HTMLParseError that it failed
        # to parse the page. Other exceptions come from extractors and the
        # #result method.
        #
        # See also Base#scrape.
        def scrape()
            # Retrieve the document. This may raise HTTPError or HTMLParseError.
            case document
            when Array: stack = @document.reverse # see below
            when HTML::Node:
                # If a root element is specified, start selecting from there.
                # The stack is empty if we can't find any root element (makes
                # sense). However, the node we're going to process may be
                # a tag, or an HTML::Document.root which is the equivalent of
                # a document fragment.
                root_element = option(:root_element)
                root = root_element ? @document.find(:tag=>root_element) : @document
                stack = root ? (root.tag? ? [root] : root.children.reverse) : []
            else return
            end
            # Call prepare with the document, but before doing anything else.
            prepare
            # @skip stores all the elements we want to skip (see #skip).
            # rules stores all the rules we want to process with this
            # scraper, based on the class definition.
            @skip = []
            @stop = false
            rules = self.class.rules
            begin
                # Process the document one node at a time. We process elements
                # from the end of the stack, so each time we visit child elements,
                # we add them to the end of the stack in reverse order.
                while node = stack.pop
                    break if @stop
                    skip_this = false
                    # Only match nodes that are elements, ignore text nodes.
                    # Also ignore any element that's on the skip list, and if
                    # found one, remove it from the list (since we never visit
                    # the same element twice). But an element may be added twice
                    # to the skip list.
                    # Note: equal? is faster than == for nodes.
                    next unless node.tag?
                    @skip.delete_if { |s| skip_this = true if s.equal?(node) }
                    next if skip_this

                    # Run through all the rules until we process the element or
                    # run out of rules. If skip_this=true then we processed the
                    # element and we can break out of the loop. However, we might
                    # process (and skip) descedants so also watch the skip list.
                    rules.each do |selector, extractor|
                        break if skip_this
                        # The result of calling match (selected) is nil, element
                        # or array of elements. We turn it into an array to
                        # process one element at a time. We process all elements
                        # that are not on the skip list (we haven't visited
                        # them yet).
                        if selected = selector.match(node)
                            selected = [selected] unless selected.is_a?(Array)
                            selected.each do |element|
                                # Do not process elements we already skipped
                                # (see above). However, this time we may visit
                                # an element twice, since selected elements may
                                # be descendants of the current element on the
                                # stack. In rare cases two elements on the stack
                                # may pick the same descendants.
                                next if @skip.find { |s| s.equal?(element) }
                                # Call the extractor method with this element.
                                # If it returns true, skip the element and if
                                # the current element, don't process any more
                                # rules. Again, pay attention to descendants.
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
            ensure
                @skip = @element = nil
            end
            return result
        end


        # Returns the document being processed.
        #
        # If the scraper was created with a URL, this method will attempt to
        # retrieve the page and parse it.
        #
        # If the scraper was created with a string, this method will attempt
        # to parse the page.
        #
        # Be advised that calling this method may raise an exception
        # (HTTPError or HTMLParseError).
        #
        # The document is parsed only the first time this method is called.
        def document
            unless @document
                if @source.is_a?(URI)
                    # Attempt to read page. May raise HTTPError.
                    options = {}
                    READER_OPTIONS.each { |key| options[key] = option(key) }
                    if page = Reader.read_page(@source, options)
                        @page_info.url = page.url
                        @page_info.original_url = @source
                        @page_info.last_modified = page.last_modified
                        @page_info.etag = page.etag
                        @page_info.encoding = page.encoding
                        @source = page.content
                    end
                end
                if @source.is_a?(String)
                    # Parse the page. May raise HTMLParseError.
                    parsed = Reader.parse_page(@source, @page_info.encoding,
                        option(:tidy_options))
                    @document = parsed.document
                    @page_info.encoding = parsed.encoding
                elsif @source.is_a?(HTML::Node)
                    @document = @source
                end
            end
            return @document
        end


        # :call-seq:
        #   skip() => true
        #   skip(element) => true
        #   skip([element ...]) => true
        #
        # Skips processing the specified element(s).
        #
        # If called with a single element, that element will not be processed.
        #
        # If called with an array of elements, all the elements in the array
        # are skipped.
        #
        # If called with no element, skips processing the current element.
        # This has the same effect as returning true.
        #
        # For convenience this method always returns true. For example:
        #   process "h1" do |element|
        #     @header = element
        #     skip
        #   end
        def skip(elements = nil)
            case elements
            when Array: @skip += elements
            when HTML::Node: @skip << elements
            when nil: @skip << self.element
            end
            # Calling skip(element) as the last statement is
            # redundant by design.
            return true
        end


        # Stops processing this page. You can call this early on if you
        # discover there is no interesting information on the page, or
        # done extracting all useful information.
        def stop()
            @stop = true
        end


        # Called by #scrape after creating the document, but before running
        # any processing rules.
        #
        # You can override this method to do any preparation work. The document
        # is accessible by calling #document.
        def prepare()
        end


        # Returns the result of a succcessful scrape.
        #
        # This method is called by #scrape after running all the rules on the
        # document. You can also call it directly.
        #
        # Override this method to return a specific object, perform post-scraping
        # processing, validation, etc.
        #
        # The default implementation returns +self+ if any extractor returned
        # true, +nil+ otherwise.
        #
        # If you override this method, implement your own logic to determine
        # if anything was extracted and return +nil+ otherwise. Also, make sure
        # calling this method multiple times returns the same result.
        def result()
            return self if @extracted
        end


        # Returns the value of an option.
        #
        # Returns the value of an option passed to the scraper on creation.
        # If not specified, return the value of the option set for this
        # scraper class. Options are inherited from the parent class.
        def option(symbol)
            return options.has_key?(symbol) ? options[symbol] :
                self.class.options[symbol]
        end


    end

end
