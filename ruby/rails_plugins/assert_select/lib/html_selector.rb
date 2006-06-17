module HTML

    # Selects HTML elements using CSS 2 selectors.
    #
    # The +Selector+ class uses CSS selector expressions to match and select
    # HTML elements.
    #
    # For example:
    #   selector = HTML::Selector.new "form.login[action=/login]"
    # creates a new selector that matches any +form+ element with the class
    # +login+ and an attribute +action+ with the value <tt>/login</tt>.
    #
    # === Matching Elements
    #
    # Use the #match method to determine if an element matches the selector.
    #
    # For simple selectors, the method returns an array with that element,
    # or +nil+ if the element does not match. For complex selectors (see below)
    # the method returns an array with all matched elements, of +nil+ if no
    # match found.
    #
    # For example:
    #   if selector.match(element)
    #     puts "Element is a login form"
    #   end
    #
    # === Selecting Elements
    #
    # Use the #select method to select all matching elements starting with
    # one element and going through all children in depth-first order.
    #
    # This method returns an array of all matching elements, an empty array
    # if no match is found
    #
    # For example:
    #   selector = HTML::Selector.new "input[type=text]"
    #   matches = selector.select(element)
    #   matches.each do |match|
    #     puts "Found text field with name #{match.attributes['name']}"
    #   end
    #
    # === Expressions
    #
    # Selectors can match elements using any of the following criteria:
    # * <tt>name</tt> -- Match an element based on its name (tag name).
    #   For example, <tt>p</tt> to match a paragraph. You can use <tt>*</tt>
    #   to match any element.
    # * <tt>#</tt><tt>id</tt> -- Match an element based on its identifier (the
    #   <tt>id</tt> attribute). For example, <tt>#</tt><tt>page</tt>.
    # * <tt>.class</tt> -- Match an element based on its class name, all
    #   class names if more than one specified.
    # * <tt>[attr]</tt> -- Match an element that has the specified attribute.
    # * <tt>[attr=value]</tt> -- Match an element that has the specified
    #   attribute and value. (More operators are supported see below)
    #
    # When using a combination of the above, the element name comes first
    # followed by the identifier, followed by class names followed by the
    # attributes. Do not separate with spaces.
    #
    # For example:
    #   selector = HTML::Selector.new "form.login[action=/login]"
    # The matched element must be of type +form+ and have the class +login+.
    # It may have other classes, but the class +login+ is required to match.
    # It must also have an attribute called +action+ with the value
    # <tt>/login</tt>.
    #
    # This selector will match the following element:
    #   <form class="login form" method="post" action="/login">
    # but will not match the element:
    #   <form method="post" action="/logout">
    #
    # === Attribute Values
    #
    # Several operators are supported for matching attributes:
    # * <tt>name</tt> -- The element must have an attribute with that name.
    # * <tt>name=value</tt> -- The element must have an attribute with that
    #   name and value.
    # * <tt>name^=value</tt> -- The attribute value must start with the
    #   specified value.
    # * <tt>name$=value</tt> -- The attribute value must end with the
    #   specified value.
    # * <tt>name*=value</tt> -- The attribute value must contain the
    #   specified value.
    # * <tt>name~=word</tt> -- The attribute value must contain the specified
    #   word (space separated).
    # * <tt>name|=word</tt> -- The attribute value must start with specified
    #   word.
    #
    # For example, the following two selectors match the same element:
    #   #my_id
    #   [id=my_id]
    # and so do the following two selectors:
    #   .my_class
    #   [class~=my_class]
    #
    # === Alternatives, siblings, children
    #
    # Complex selectors use a combination of expressions to match elements:
    # * <tt>expr1 expr2</tt> -- Match any element against the second expression
    #   if it has some parent element that matches the first expression.
    # * <tt>expr1 > expr2</tt> -- Match any element against the second expression
    #   if it is the child of an element that matches the first expression.
    # * <tt>expr1 + expr2</tt> -- Match any element against the second expression
    #   if it immediately follows an element that matches the first expression.
    # * <tt>expr1 ~ expr2</tt> -- Match any element against the second expression
    #   that comes after an element that matches the first expression.
    # * <tt>expr1, expr2</tt> -- Match any element against the first expression,
    #   or against the second expression.
    #
    # Since children and sibling selectors may match more than one element given
    # the first element, the #match method may return more than one match.
    #
    # === Substitution Values
    #
    # You can use substitution with identifiers, class names and element values.
    # A substitution takes the form of a question mark (<tt>?</tt>) and uses the
    # next value in the argument list following the CSS expression.
    #
    # The substitution value may be a string or a regular expression. All other
    # values are converted to strings.
    #
    # For example:
    #   selector = HTML::Selector.new "#?", /^\d+$/
    # matches any element whose identifier consists of one or more digits.
    class Selector


        # An invalid selector.
        class InvalidSelectorError < StandardError
        end
    
    
        # Parse each selector into six parts:
        # $1 element name or * (optional)
        # $2 ID name (including leading #, optional, #? allowed)
        # $3 class names (including leading ., zero or more)
        # $4 attribute expressions (zero or more)
        # $5 separator/operator (empty, +, >, etc)
        # $6 anything else (no leading spaces)
        unless const_defined? :REGEX
            REGEX = /^(\*|[[:alpha:]][\w\-:]*)?(#(?:\?|[\w\-:]+))?((?:\.[\w\-:]*){0,})((?:\[[[:alpha:]][\w\-:][^\]]*\]){0,})\s*([,+>~]?)\s*(.*)$/ #:nodoc:
        end

        # Parse each attribute expression into three parts:
        # $1 attribute name
        # $2 matching operation
        # $3 matched value
        # Matching operation may be =, ~= or |=, etc (or nil).
        # Value may be empty.
        unless const_defined? :ATTR_REGEX
            ATTR_REGEX = /^([A-Za-z0-9_\-:]*)((?:[~|^$*])?=)?(.*)$/ #:nodoc:
        end


        # :call-seq:
        #   Selector.new(string, [values ...]) => selector
        #
        # Creates a new selector from a CSS 2 selector expression.
        #
        # The first argument is the selector expression. All other arguments
        # are used for value substitution.
        #
        # Throws InvalidSelectorError is the selector expression is invalid.
        def initialize(statement, *values)
            raise ArgumentError, "CSS expression cannot be empty" if statement.empty?
            @source = statement = statement.strip
            # Parse the first selector expression into $1-$4, anything else goes in $5
            parts = Selector::REGEX.match(statement)
            raise InvalidSelectorException, "Invalid (empty) selector statement" if parts[0].length == 0
    
            # Set tag_name to the element name if specified and not *
            @tag_name = parts[1] if parts[1] and !parts[1].empty? and parts[1] != '*'
            # This array holds the regular expressions for matching attributes.
            # We use an array since we allow multiple expressions on the same attribute,
            # e.g. to find an element with both class 'foo' and class 'bar'.
            @attrs = []

            # Match the ID attribute if specified
            unless parts[2].nil? || parts[2].empty?
                value = parts[2][1..-1]
                value = values.shift if value == "?"
                value = Regexp.new('^' + value.to_s + '$') unless value.is_a?(Regexp)
                @attrs << ["id", value]
            end

            # The third part is a collection of class names, prefixed with dot
            # Create an attribute matching regular expression for each class
            # The class attribute is a set of space-separated names, so match accordingly
            unless parts[3].empty?
                parts[3].split('.').each do |value|
                    unless value.empty?
                        value = values.shift if value == "?"
                        value = Regexp.new('(^|\s)' + value.to_s + '($|\s)') unless value.is_a?(Regexp)
                        @attrs << ["class", value]
                    end
                end
            end

            # Process the remaining attribute expressions. Each expression is enclosed
            # within square brackets, so split the expressions into anything between the
            # square brackets. The result may include empty elements, skip those.
            parts[4].split(/\[|\]/).each do |expr|
                if not expr.empty?
                    # Parse the attribute expression and created a regular expression
                    # for matching the attribute value, based on the operation.
                    name, type, value = ATTR_REGEX.match(expr)[1..3]
                    value = values.shift if value == "?"
                    case type
                    when "=" then
                        # Match the attribute value in full
                        match = value.is_a?(Regexp) ? value : Regexp.new("^" + value.to_s + "$")
                    when "~=" then
                        # Match a space-separated word within the attribute value
                        match = Regexp.new("(^|\s)" + value.to_s + "($|\s)")
                    when "^="
                        # Match the beginning of the attribute value
                        match = Regexp.new("^" + value.to_s)
                    when "$="
                        # Match the end of the attribute value
                        match = Regexp.new(value.to_s + "$")
                    when "*="
                        # Match substring of the attribute value
                        match = Regexp.new(value.to_s)
                    when "|=" then
                        # Match the first space-separated item of the attribute value
                        match = Regexp.new("^" + value.to_s + "($|\s)")
                    else
                        raise InvalidSelectorError, "Invalid value matching operator in #{parts[4]}" if !value.empty?
                        # Match all attributes values (existence check)
                        match = Regexp.new("")
                    end
                    @attrs << [name, match]
                end
            end
    
            if !parts[6].empty?
                raise ArgumentError, "Invalid CSS expression" if statement == parts[6]
                second = Selector.new(parts[6], *values)
                # Create a compound selector based on the remainder of the statement.
                # This is also why we need the factory and can't call new directly.
                case parts[5]
                when ","
                    # Alternative selector: second statement is alternative to the first one,
                    # so no dependency.
                    @alt = second
                when "+"
                    # Sibling selector: second statement is returned that will match element
                    # following current element.
                    @depends = proc do |element|
                        element = next_element(element)
                        return element ? second.match(element) : nil
                    end
                when "~"
                    # Sibling (indirect) selector: second statement is returned that will match
                    # element following the current element.
                    @depends = proc do |element|
                        matches = []
                        while element = next_element(element)
                            if subset = second.match(element)
                                matches += subset
                            end
                        end
                        matches.empty? ? nil : matches
                    end
                when ">"
                    # Child selector: second statement is returned that will match element
                    # that is a child of this element.
                    @depends = proc do |element|
                        matches = []
                        element.children.each do |child|
                            if child.tag? and subset = second.match(child)
                                matches += subset
                            end
                        end
                        matches.empty? ? nil : matches
                    end
                else
                    # Descendant selector: second statement is returned that will match all
                    # element that are children of this element.
                    @depends = proc do |element|
                        matches = []
                        stack = element.children.reverse
                        while node = stack.pop
                            next unless node.tag?
                            if subset = second.match(node)
                                matches += subset
                            elsif children = node.children
                                stack += children.reverse
                            end
                        end
                        matches.empty? ? nil : matches
                    end
                end
            end
        end


        # :call-seq:
        #   Selector.for_class(cls) => selector
        #
        # Creates a new selector for the given class name.
        def self.for_class(cls)
            self.new([".?", cls])
        end
    
    
        # :call-seq:
        #   Selector.for_id(id) => selector
        #
        # Creates a new selector for the given id.
        def self.for_id(id)
            self.new(["#?", id])
        end


        # :call-seq:
        #   match(element) => array or nil
        #
        # Matches an element against the selector.
        #
        # For a simple selector this method returns an array with the
        # element if the element matches, nil otherwise.
        #
        # For a complex selector (sibling and descendant) this method
        # returns an array with all matching elements, nil if no match is
        # found.
        #
        # For example:
        #   if selector.match(element)
        #     puts "Element is a login form"
        #   end
        def match(element)
            # Match element if no element name or element name same as element name
            if matched = (!@tag_name or @tag_name == element.name)
                # No match if one of the attribute matches failed
                for attr in @attrs
                    if element.attributes[attr[0]] !~attr[1]
                        matched = false
                        break
                    end
                end
            end
            # If the element did not match, but we have an alternative match
            # (x+y), apply the alternative match instead
            return @alt.match(element) if not matched and @alt
            # If the element did match, but depends on another match (child,
            # sibling, etc), apply the dependent match instead.
            return @depends.call(element) if matched and @depends
            matched ? [element] : nil
        end


        # :call-seq:
        #   select(root) => array
        #
        # Selects and returns an array with all matching elements, beginning
        # with one node and traversing through all children depth-first.
        # Returns an empty array if no match is found.
        #
        # The root node may be any element in the document, or the document
        # itself.
        #
        # For example:
        #   selector = HTML::Selector.new "input[type=text]"
        #   matches = selector.select(element)
        #   matches.each do |match|
        #     puts "Found text field with name #{match.attributes['name']}"
        #   end
        def select(root)
            matches = []
            stack = [root]
            while node = stack.pop
                if node.tag? && subset = match(node)
                    subset.each do |match|
                        matches << match unless matches.any? { |item| item.equal?(match) }
                    end
                elsif children = node.children
                    stack += children.reverse
                end
            end
            matches
        end


        def inspect #:nodoc:
            @source || to_s
        end


        # Return the next element after this one. Skips sibling text nodes.
        #
        # With the +name+ argument, returns the next element with that name,
        # skipping other sibling elements.
        def next_element(element, name = nil)
            if siblings = element.parent.children
                found = false
                siblings.each do |node|
                    if node.equal?(element)
                        found = true
                    elsif found && node.tag?
                        return node if (name.nil? || node.name == name)
                    end
                end
            end
            return nil
        end

    end

end
