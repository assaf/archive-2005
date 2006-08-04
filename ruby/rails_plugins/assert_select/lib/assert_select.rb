# assert_select plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


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
        # See assert_select to understand what's going on here.
        arg = args.shift
        if arg.is_a?(HTML::Node)
          root = arg
          arg = args.shift
        elsif arg == nil
          raise ArgumentError, "First arugment is either selector or element to select, but nil found. Perhaps you called assert_select with an element that does not exist?"
        elsif @selected
          matches = []
          @selected.each do |selected|
            subset = css_select(selected, HTML::Selector.new(arg.dup, args.dup))
            subset.each do |match|
              matches << match unless matches.any? { |m| m.equal?(match) }
            end
          end
          return matches
        else
          root = response_from_page_or_rjs
        end
        case arg
          when String
            selector = HTML::Selector.new(arg, args)
          when Array
            selector = HTML::Selector.new(*arg)
          when HTML::Selector 
            selector = arg
          else raise ArgumentError, "Expecting a selector as the first argument"
        end

        selector.select(root)  
      end


      # :call-seq:
      #   assert_select(selector, equality?, message?)
      #   assert_select(element, selector, equality?, message?)
      #
      # An assertion that selects elements and makes one or more equality tests.
      #
      # If the first argument is an element, selects all matching elements
      # starting from (and including) that element and all its children in
      # depth-first order.
      #
      # If no element if specified, calling #assert_select will select from the
      # response HTML. Calling #assert_select inside an #assert_select block will
      # run the assertion for each element selected by the enclosing assertion.
      #
      # For example:
      #   assert_select "ol>li" do |elements|
      #     elements.each do |element|
      #       assert_select element, "li"
      #     end
      #   end
      # Or for short:
      #   assert_select "ol>li" do
      #     assert_select "li"
      #   end
      #
      # The selector may be a CSS selector expression (+String+), an expression
      # with substitution values, or an HTML::Selector object.
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
      # * <tt>:text</tt> -- Assertion is true if the text value of each
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
      #   # Use substitution values
      #   assert_select "ol>li#?", /item-\d+/
      #
      #   # All input fields in the form have a name
      #   assert_select "form input" do
      #     assert_select "[name=?]", /.+/  # Not empty
      #   end
      def assert_select(*args, &block)
        # Start with optional element followed by mandatory selector.
        arg = args.shift
        if arg.is_a?(HTML::Node)
          # First argument is a node (tag or text, but also HTML root),
          # so we know what we're selecting from.
          root = arg
          arg = args.shift
        elsif arg == nil
          # This usually happens when passing a node/element that
          # happens to be nil.
          raise ArgumentError, "First arugment is either selector or element to select, but nil found. Perhaps you called assert_select with an element that does not exist?"
        elsif @selected
          root = HTML::Node.new(nil)
          root.children.concat @selected
        else
          # Otherwise just operate on the response document.
          root = response_from_page_or_rjs
        end

        # First or second argument is the selector: string and we pass
        # all remaining arguments. Array and we pass the argument. Also
        # accepts selector itself.
        case arg
          when String
            selector = HTML::Selector.new(arg, args)
          when Array
            selector = HTML::Selector.new(*arg)
          when HTML::Selector 
            selector = arg
          else raise ArgumentError, "Expecting a selector as the first argument"
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
          when FalseClass
            equals[:count] = 0
          when NilClass, TrueClass
            equals[:minimum] = 1
          else raise ArgumentError, "I don't understand what you're trying to match"
        end
        # If we have a text test, by default we're looking for at least one match.
        # Without this statement text tests pass even if nothing is selected.
        # Can always override by specifying minimum or count.
        if equals[:text]
          equals[:minimum] ||= 1
        end
        # If a count is specified, it takes precedence over minimum/maximum.
        if equals[:count]
          equals[:minimum] = equals[:maximum] = equals.delete(:count)
        end

        # Last argument is the message we use if the assertion fails.
        message = args.shift
        #- message = "No match made with selector #{selector.inspect}" unless message
        if args.shift
          raise ArgumentError, "Not expecting that last argument, you either have too many arguments, or they're the wrong type"
        end

        matches = selector.select(root)  
        # Equality test.
        equals.each do |type, value|
          case type
            when :text
              for match in matches
                text = ""
                stack = [match]
                unless stack.empty?
                  while node = stack.pop
                    if node.tag?
                      stack += node.children.reverse
                    else
                      text << node.content
                    end
                  end
                end
                if value.is_a?(Regexp)
                  assert value =~ text, message || "Text content \"#{text}\" does not match one or more selected elements"
                else
                  assert_equal value.to_s, text, message || "Text content \"#{text}\" does not match one or more selected elements"
                end
              end
            when :minimum
              assert matches.size >= value, message || "Expecting at least #{value} selected elements, found #{matches.size}"
            when :maximum
              assert matches.size <= value, message || "Expecting at most #{value} selected elements, found #{matches.size}"
            else raise ArgumentError, "I don't support the equality test #{key}"
          end
        end

        # If a block is given call that block. Set @selected to allow
        # nested assert_select, which can be nested several levels deep.
        if block_given? and !matches.empty?
          begin
            in_scope, @selected = @selected, matches
            yield matches
          ensure
            @selected = in_scope
          end
        end

        # Returns all matches elements.
        matches
      end


      # :call-seq:
      #   assert_select_rjs(id?) { |elements| ... }
      #   assert_select_rjs(statement, id?) { |elements| ... }
      #   assert_select_rjs(:insert, position, id?) { |elements| ... }
      #
      # Selects content from the RJS response.
      #
      # === Narrowing down
      #
      # With no arguments, asserts that one or more elements are updated or
      # inserted by RJS statements.
      #
      # Use the +id+ argument to narrow down the assertion to only statements
      # that update or insert an element with that identifier.
      #
      # Use the first argument to narrow down assertions to only statements
      # of that type. Possible values are +:replace+, +:replace_html+ and
      # +:insert_html+.
      #
      # Use the argument +:insert+ followed by an insertion position to narrow
      # down the assertion to only statements that insert elements in that
      # position. Possible values are +:top+, +:bottom+, +:before+ and +:after+.
      #
      # === Using blocks
      #
      # Without a block, #assert_select_rjs merely asserts that the response
      # contains one or more RJS statements that replace or update content.
      #
      # With a block, #assert_select_rjs also selects all elements used in
      # these statements and passes them to the block. Nested assertions are
      # supported.
      #
      # Calling #assert_select_rjs with no arguments and using nested asserts
      # asserts that the HTML content is returned by one or more RJS statements.
      # Using #assert_select directly makes the same assertion on the content,
      # but without distinguishing whether the content is returned in an HTML
      # or JavaScript.
      #
      # === Examples
      #
      #   # Updating the element foo.
      #   assert_select_rjs :update, "foo"
      #
      #   # Inserting into the element bar, top position.
      #   assert_select rjs, :insert, :top, "bar"
      #
      #   # Changing the element foo, with an image.
      #   assert_select_rjs "foo" do
      #     assert_select "img[src=/images/logo.gif""
      #   end
      #
      #   # RJS inserts or updates a list with four items.
      #   assert_select_rjs do
      #     assert_select "ol>li", 4
      #   end
      #
      #   # The same, but shorter.
      #   assert_select "ol>li", 4
      def assert_select_rjs(*args, &block)
        arg = args.shift
        # If the first argument is a symbol, it's the type of RJS statement we're looking
        # for (update, replace, insertion, etc). Otherwise, we're looking for just about
        # any RJS statement.
        if arg.is_a?(Symbol)
          if arg == :insert
            arg = args.shift
            insertion = "insert_#{arg}".to_sym
            raise ArgumentError, "Unknown RJS insertion type #{arg}" unless RJS_STATEMENTS[insertion]
            statement = "(#{RJS_STATEMENTS[insertion]})"
          else
            raise ArgumentError, "Unknown RJS statement type #{arg}" unless RJS_STATEMENTS[arg]
            statement = "(#{RJS_STATEMENTS[arg]})"
          end
          arg = args.shift
        else
          statement = "#{RJS_STATEMENTS[:any]}"
        end

        # Next argument we're looking for is the element identifier. If missing, we pick
        # any element.
        if arg.is_a?(String)
          id = Regexp.quote(arg)
          arg = args.shift
        else
          id = "[^\"]*"
        end

        pattern = Regexp.new("#{statement}\\(\"#{id}\", #{RJS_PATTERN_HTML}\\)", Regexp::MULTILINE)
          
        # Duplicate the body since the next step involves destroying it.
        matches = nil
        @response.body.gsub(pattern) do |match|
          html = $2
          # RJS encodes double quotes and line breaks.
          html.gsub!(/\\"/, "\"")
          html.gsub!(/\\n/, "\n")
          matches ||= []
          matches.concat HTML::Document.new(html).root.children.select { |n| n.tag? }
          ""
        end
        if matches
          if block_given?
            begin
              in_scope, @selected = @selected, matches
              yield matches
            ensure
              @selected = in_scope
            end
          end
          matches
        else
          # RJS statement not found.
          flunk args.shift || "No RJS statement that replaces or inserts HTML content."
        end
      end


    protected

      unless const_defined?(:RJS_STATEMENTS)
        RJS_STATEMENTS = {
          :replace      => /Element\.replace/,
          :replace_html => /Element\.update/
        }
        RJS_INSERTIONS = [:top, :bottom, :before, :after]
        RJS_INSERTIONS.each do |insertion|
          RJS_STATEMENTS["insert_#{insertion}".to_sym] = Regexp.new(Regexp.quote("new Insertion.#{insertion.to_s.camelize}"))
        end
        RJS_STATEMENTS[:any] = Regexp.new("(#{RJS_STATEMENTS.values.join('|')})")
        RJS_STATEMENTS[:insert_html] = Regexp.new(RJS_INSERTIONS.collect do |insertion|
          Regexp.quote("new Insertion.#{insertion.to_s.camelize}")
        end.join('|'))
        RJS_PATTERN_HTML = /"((\\"|[^"])*)"/
        RJS_PATTERN_EVERYTHING = Regexp.new("#{RJS_STATEMENTS[:any]}\\(\"([^\"]*)\", #{RJS_PATTERN_HTML}\\)",
                                            Regexp::MULTILINE)
      end


      # #assert_select and #css_select call this to obtain the content in the HTML
      # page, or from all the RJS statements, depending on the type of response.
      def response_from_page_or_rjs()
        content_type = @response.headers["Content-Type"]
        if content_type and content_type =~ /text\/javascript/
          body = @response.body.dup
          root = HTML::Node.new(nil)
          while true
            next if body.sub!(RJS_PATTERN_EVERYTHING) do |match|
              # RJS encodes double quotes and line breaks.
              html = $3
              html.gsub!(/\\"/, "\"")
              html.gsub!(/\\n/, "\n")
              matches = HTML::Document.new(html).root.children.select { |n| n.tag? }
              root.children.concat matches
              ""
            end
            break
          end
          root
        else
          html_document.root
        end
      end

    end
  end
end
