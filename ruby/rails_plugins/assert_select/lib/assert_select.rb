require "test/unit"
require File.join(File.dirname(__FILE__), "html_selector")

module Test #:nodoc:
    module Unit #:nodoc:

        # Adds the #assert_select method for use in Rails functional
        # test cases.
        #
        # Also see HTML::Selector for learning how to use selectors.
        module AssertSelect 

            # :call-seq:
            #   css_select(selector) => array
            #   css_select(element, selector) => array
            #
            # Select and return all matching elements.
            #
            # If called with a single argument, uses that argument as a selector
            # to match all elements of the current page. Returns an empty array
            # if no match is found.
            #
            # If called with two arguments, uses the first argument as the base
            # element and the second argument as the selector. Attempts to match the
            # base element and any of its children. Returns an empty array if no
            # match is found.
            #
            # The selector may be a CSS selector expression (+String+), an expression
            # with substitution values (+Array+) or an HTML::Selector object.
            #
            # For example:
            #   forms = css_select("form")
            #   forms.each do |form|
            #     inputs = css_select(form, "input")
            #     ...
            #   end
            def css_select(*args)
                arg = args.shift
                if arg.is_a?(HTML::Tag)
                    element = arg
                    arg = args.shift
                else
                    element = html_document.root
                end

                raise ArgumentError, "Selector missing" unless arg
                case arg
                when String
                    selector = HTML::Selector.new(arg, *args)
                when Array
                    selector = HTML::Selector.new(*arg)
                when HTML::Selector
                    selector = arg
                else
                    raise ArgumentError, "Expecting a selector"
                end

                selector.select(element)  
            end


            # :call-seq:
            #   assert_select(selector, equality?, message?)
            #   assert_select(element, selector, equality?, message?)
            #
            # An assertion that selects elements and makes one or more equality tests.
            #
            # If the first argument is an element, selects all matching elements
            # starting from (and including) that element and all its children in
            # depth-first order. Otherwise, uses the current page.
            #
            # The selector may be a CSS selector expression (+String+), an expression
            # with substitution values (+Array+) or an HTML::Selector object.
            #
            # === Equality Tests
            #
            # The equality test may be one of the following:
            # * <tt>nil/true</tt> -- Assertion is true if at least one element is
            #   selected.
            # * <tt>String</tt> -- Assertion is true if the text value of all
            #   selected elements equals to the string.
            # * <tt>Regexp</tt> -- Assertion is true if the text value of all
            #   selected elements matches the regular expression.
            # * <tt>false</tt> -- Assertion is true if no element is selected.
            # * <tt>Integer</tt> -- Assertion is true if exactly that number of
            #   elements are selected.
            # * <tt>Range</tt> -- Assertion is true if the number of selected
            #   elements fit the range.
            #
            # To perform more than one equality tests, use a hash the following keys:
            # * <tt>:text</tt> -- Assertion is true if the text value of all
            #   selected elements equals to the value (+String+ or +Regexp+).
            # * <tt>:count</tt> -- Assertion is true if the number of matched elements
            #   is equal to the value.
            # * <tt>:minimum</tt> -- Assertion is true if the number of matched
            #   elements is at least that value.
            # * <tt>:maximum</tt> -- Assertion is true if the number of matched
            #   elements is at most that value.
            #
            # If the method is called with a block, once all equality tests are
            # evaluated the block is called with an array of all matched elements.
            #
            # === Examples
            # 
            #   # At least one form element
            #   assert_select "form"
            #
            #   # Form element includes four input fields
            #   assert_select "form input", 4
            #
            #   # Page title is "Welcome"
            #   assert_select "title", "Welcome"
            #
            #   # Page title is "Welcome" and there is only one title element
            #   assert_select "title", {:count=>1, :text=>"Welcome"},
            #       "Wrong title or more than one title element"
            #
            #   # Page contains no forms
            #   assert_select "form", false, "This page must contain no forms"
            #
            #   # Test the content and style
            #   assert_select "body div.header ul.menu"
            #
            #   # All input fields in the form have a name
            #   assert_select "form input" do |elements|
            #     elements.each do |element|
            #       assert not element.attributes["name"].empty?
            #     end
            #   end
            def assert_select(*args)
                # Start with element and selector, or just element.
                arg = args.shift
                if arg.is_a?(HTML::Tag)
                    element = arg
                    arg = args.shift
                else
                    element = html_document.root
                end

                raise ArgumentError, "Selector missing" unless arg
                case arg
                when String
                    selector = HTML::Selector.new(arg, *args)
                when Array
                    selector = HTML::Selector.new(*arg)
                when HTML::Selector
                    selector = arg
                else
                    raise ArgumentError, "Expecting a selector"
                end

                # Next argument is used for equality tests.
                equals = {}
                case arg = args.shift
                when Hash
                    equals = arg
                when String, Regexp
                    equals[:text] = arg
                when Integer
                    equals[:count] = arg
                when Range
                    equals[:minimum] = arg.begin
                    equals[:maximum] = arg.end
                when nil, true
                    equals[:minimum] = 1
                when false
                    equals[:count] = 0
                else
                    raise ArgumentError, "I don't understand what you're trying to match"
                end
                # Last argument is the message we use if the assertion fails.
                message = args.shift
                message = "No match made with selector #{selector.inspect}" unless message
                raise ArgumentError, "Not expecting that last argument, you either have too many arguments, or they're the wrong type" if args.shift

                # Select elements.
                matches = selector.select(element)  
                # Equality test.
                equals.each do |type, value|
                    case type
                    when :text
                        stack = matches.clone
                        text = ""
                        while node = stack.pop
                            if node.tag?
                                stack += node.children.reverse
                            else
                                text << node.content
                            end
                        end
                        if value.is_a?(Regexp)
                            assert value =~ text, message
                        else
                            assert_equal value.to_s, text, message
                        end
                    when :count
                        assert_equal value, matches.size, message
                    when :minimum
                        assert matches.size >= value, message
                    when :maximum
                        assert matches.size <= value, message
                    else
                        raise ArgumentError, "I don't support the equality test #{key}"
                    end
                end
                    
                yield matches if block_given?
                matches
            end

        end
    end
end
