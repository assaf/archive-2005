# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


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
  #
  # See http://www.w3.org/TR/css3-selectors/
  class Selector


    # An invalid selector.
    class InvalidSelectorError < StandardError ; end


    unless const_defined? :REGEX
      # Parse each attribute expression into three parts:
      # $1 attribute name
      # $2 matching operation
      # $3 matched value
      # Matching operation may be =, ~= or |=, etc (or nil).
      # Value may be empty.
      ATTR_REGEXP = /^\s*([A-Za-z0-9_\-]*)\s*((?:[~|^$*])?=)?\s*(.*)$/ #:nodoc:

      # TODO: More regular selections based on CSS3 lexical rules.
    end


    class << self

      # :call-seq:
      #   Selector.for_class(cls) => selector
      #
      # Creates a new selector for the given class name.
      def for_class(cls)
        self.new([".?", cls])
      end


      # :call-seq:
      #   Selector.for_id(id) => selector
      #
      # Creates a new selector for the given id.
      def for_id(id)
        self.new(["#?", id])
      end

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
    def initialize(selector, *values)
      raise ArgumentError, "CSS expression cannot be empty" if selector.empty?
      @source = ""
      # We need a copy to determine if we failed to parse, and also
      # preserve the original pass by-ref statement.
      statement = selector.strip.dup
      # Create a simple selector, along with negation.
      simple_selector(statement, values).each { |name, value| instance_variable_set("@#{name}", value) }

      # Alternative selector.
      if statement.sub!(/^\s*,\s*/, "")
        second = Selector.new(statement, *values)
        (@alternates ||= []) << second
        # If there are alternate selectors, we group them in the top selector.
        if alternates = second.instance_variable_get(:@alternates)
          second.instance_variable_set(:@alternates, nil)
          @alternates.concat alternates
        end
        @source << " , " << second.to_s
      # Sibling selector: create a dependency into second selector that will
      # match element immediately following this one.
      elsif statement.sub!(/^\s*\+\s*/, "")
        second = next_selector(statement, *values)
        @depends = lambda do |element, first|
          if element = next_element(element)
            second.match(element, first)
          end
        end
        @source << " + " << second.to_s
      # Adjacent selector: create a dependency into second selector that will
      # match all elements following this one.
      elsif statement.sub!(/^\s*~\s*/, "")
        second = next_selector(statement, *values)
        @depends = lambda do |element, first|
          matches = []
          while element = next_element(element)
            if subset = second.match(element, first)
              if first && !subset.empty?
                matches << subset.first
                break
              else
                matches.concat subset
              end
            end
          end
          matches.empty? ? nil : matches
        end
        @source << " ~ " << second.to_s
      # Child selector: create a dependency into second selector that will
      # match a child element of this one.
      elsif statement.sub!(/^\s*>\s*/, "")
        second = next_selector(statement, *values)
        @depends = lambda do |element, first|
          matches = []
          element.children.each do |child|
            if child.tag? and subset = second.match(child, first)
              if first && !subset.empty?
                matches << subset.first
                break
              else
                matches.concat subset
              end
            end
          end
          matches.empty? ? nil : matches
        end
        @source << " > " << second.to_s
      # Descendant selector: create a dependency into second selector that
      # will match all descendant elements of this one.
      elsif statement =~ /^\s+\S+/ and statement != selector
        second = next_selector(statement, *values)
        @depends = lambda do |element, first|
          matches = []
          stack = element.children.reverse
          while node = stack.pop
            next unless node.tag?
            if subset = second.match(node, first)
              if first && !subset.empty?
                matches << subset.first
                break
              else
                matches.concat subset
              end
            elsif children = node.children
              stack.concat children.reverse
            end
          end
          matches.empty? ? nil : matches
        end
        @source << " " << second.to_s
      else
        # The last selector is where we check that we parsed
        # all the parts.
        unless statement.empty? or statement.strip.empty?
          raise ArgumentError, "Invalid selector: #{statement}"
        end
      end
    end


    # :call-seq:
    #   match(element, first?) => array or nil
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
    # Use +first_only=true+ if you are only interested in the first element.
    #
    # For example:
    #   if selector.match(element)
    #     puts "Element is a login form"
    #   end
    def match(element, first_only = false)
      # Match element if no element name or element name same as element name
      if matched = (!@tag_name or @tag_name == element.name)
        # No match if one of the attribute matches failed
        for attr in @attributes
          if element.attributes[attr[0]] !~ attr[1]
            matched = false
            break
          end
        end
      end

      # Pseudo class matches (nth-child, empty, etc).
      if matched
        for pseudo in @pseudo
          unless pseudo.call(element)
            matched = false
            break
          end
        end
      end

      # Negation.
      if matched and @negation
        if @negation[:tag_name] == element.name
          matched = false
        else
          for attr in @negation[:attributes]
            if element.attributes[attr[0]] =~ attr[1]
              matched = false
              break
            end
          end
        end
        if matched
          for pseudo in @negation[:pseudo]
            if pseudo.call(element)
              matched = false
              break
            end
          end
        end
      end

      # If element matched but depends on another element (child,
      # sibling, etc), apply the dependent matches instead.
      if matched and @depends
        matches = @depends.call(element, first_only)
      else
        matches = matched ? [element] : nil
      end

      # If this selector is part of the group, try all the alternative
      # selectors (unless first_only).
      if @alternates and (!first_only or !matches)
        @alternates.each do |alternate|
          break if matches and first_only
          if subset = alternate.match(element, first_only)
            if matches
              matches.concat subset
            else
              matches = subset
            end
          end
        end
      end

      return matches
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
        if node.tag? && subset = match(node, false)
          subset.each do |match|
            matches << match unless matches.any? { |item| item.equal?(match) }
          end
        elsif children = node.children
          stack.concat children.reverse
        end
      end
      return matches
    end


    # Similar to #select but returns the first matching element. Returns +nil+
    # if no element matches the selector.
    def select_first(root)
      stack = [root]
      while node = stack.pop
        if node.tag? && subset = match(node, true)
          return subset.first if !subset.empty?
        elsif children = node.children
          stack.concat children.reverse
        end
      end
      return nil
    end


    def to_s #:nodoc:
      @source
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


  protected


    def simple_selector(statement, values, can_negate = true)
      tag_name = nil
      attributes = []
      pseudo = []
      negation = nil

      # Element name.
      statement.sub!(/^(\*|[[:alpha:]][\w\-]*)/) do |match|
        match.strip!
        tag_name = match.downcase unless match == "*"
        @source << match
        "" # Remove
      end

      # Get identifier, class, attribute name, pseudo or negation.
      while true
        # Element identifier.
        next if statement.sub!(/^#(\?|[\w\-]+)/) do |match|
          id = $1
          if id == "?"
            id = values.shift
          end
          @source << "##{id}"
          id = Regexp.new("^#{Regexp.escape(id.to_s)}$") unless id.is_a?(Regexp)
          attributes << ["id", id]
          "" # Remove
        end

        # Class name.
        next if statement.sub!(/^\.([\w\-]+)/) do |match|
          class_name = $1
          @source << ".#{class_name}"
          class_name = Regexp.new("(^|\s)#{Regexp.escape(class_name.to_s)}($|\s)") unless class_name.is_a?(Regexp)
          attributes << ["class", class_name]
          "" # Remove
        end

        # Attribute value.
        next if statement.sub!(/^\[\s*([[:alpha:]][\w\-]*)\s*((?:[~|^$*])?=)?\s*('[^']*'|"[^*]"|[^\]]*)\s*\]/) do |match|
          name, equality, value = $1, $2, $3
          if value == "?"
            value = values.shift
          else
            value.strip!
            if (value[0] == ?" or value[0] == ?') and value[0] == value[-1]
              value = value[1..-2]
            end
          end
          @source << "[#{name}#{equality}'#{value}']"
          attributes << [name.downcase.strip, attribute_match(equality, value)]
          "" # Remove
        end

        # Root element only.
        next if statement.sub!(/^:root/) do |match|
          pseudo << lambda do |element|
            element.parent.nil? or not element.parent.tag?
          end
          @source << ":root"
          "" # Remove
        end

        # Nth-child and variants.
        next if statement.sub!(/^:nth-(last-)?(child|of-type)\((odd|even|(\d+|\?)|(-?\d*|\?)?n([+\-]\d+|\?)?)\)/) do |match|
          reverse = $1 == "last-"
          of_type = $2 == "of-type"
          @source << ":nth-#{$1}#{$2}("
          case $3
            when "odd"
              pseudo << nth_child(2, 1, of_type, reverse)
              @source << "odd)"
            when "even"
              pseudo << nth_child(2, 2, of_type, reverse)
              @source << "even)"
            when /^(\d+|\?)$/
              b = ($1 == "?" ? values.shift : $1).to_i
              pseudo << nth_child(0, b, of_type, reverse)
              @source << "#{b})"
            when /^(-?\d*|\?)?n([+\-]\d+|\?)?$/
              a = ($1 == "?" ? values.shift :
                   $1 == "" ? 1 : $1 == "-" ? -1 : $1).to_i
              b = ($2 == "?" ? values.shift : $2).to_i
              pseudo << nth_child(a, b, of_type, reverse)
              @source << (b >= 0 ? "#{a}n+#{b})" : "#{a}n#{b})")
            else
              raise ArgumentError, "Invalid nth-child #{match}"
          end
          "" # Remove
        end
        next if statement.sub!(/^:(first|last)-(child|of-type)/) do |match|
          reverse = $1 == "last"
          of_type = $1 == "of-type"
          pseudo << nth_child(0, 1, of_type, reverse)
          @source << ":#{$1}-#{$2}"
          "" # Remove
        end
        next if statement.sub!(/^:only-(child|of-type)/) do |match|
          of_type = match =~ /of-type/
          pseudo << only_child(of_type)
          @source << ":only-#{$1}"
          "" # Remove
        end

        # Empty and content.
        next if statement.sub!(/^:empty/) do |match|
          pseudo << lambda do |element|
            empty = true
            for child in element.children
              if child.tag? or !child.content.strip.empty?
                empty = false
                break
              end
            end
            return empty
          end
          @source << ":empty"
          "" # Remove
        end
        next if statement.sub!(/^:content\(\s*('[^']*'|"[^"]*"|[^)]*)\s*\)/) do |match|
          content = $1
          if (content[0] == ?" or content[0] == ?') and content[0] == content[-1]
            content = content[1..-2]
          end
          pseudo << lambda do |element|
            text = ""
            for child in element.children
              unless child.tag?
                text << child.content
              end
            end
            return text.strip == content
          end
          @source << ":content('#{content}')"
          "" # Remove
        end

        # Negation.
        if statement.sub!(/^:not\(\s*/, "")
          raise ArgumentError, "Double negatives are not missing feature" unless can_negate
          @source << ":not("
          negation = simple_selector(statement, values, false)
          raise ArgumentError, "Negation not closed" unless statement.sub!(/^\s*\)/, "")
          @source << ")"
          next
        end

        # No match: moving on.
        break
      end

      return {:tag_name=>tag_name, :attributes=>attributes, :pseudo=>pseudo, :negation=>negation}
    end


    def attribute_match(equality, value)
      regexp = value.is_a?(Regexp) ? value : Regexp.escape(value.to_s)
      case equality
        when "=" then
          # Match the attribute value in full
          Regexp.new("^#{regexp}$")
        when "~=" then
          # Match a space-separated word within the attribute value
          Regexp.new("(^|\s)#{regexp}($|\s)")
        when "^="
          # Match the beginning of the attribute value
          Regexp.new("^#{regexp}")
        when "$="
          # Match the end of the attribute value
          Regexp.new("#{regexp}$")
        when "*="
          # Match substring of the attribute value
          regexp.is_a?(Regexp) ? regexp : Regexp.new(regexp)
        when "|=" then
          # Match the first space-separated item of the attribute value
          Regexp.new("^#{regexp}($|\s)")
        else
          raise InvalidSelectorError, "Invalid operation/value" unless value.empty?
          # Match all attributes values (existence check)
          //
      end
    end


    def nth_child(a, b, of_type, reverse)
      # a = 0 means select at index b, if b = 0 nothing selected
      return lambda { |element| false } if a == 0 and b == 0
      # a < 0 and b < 0 will never match against an index
      return lambda { |element| false } if a < 0 and b < 0
      b = a + b + 1 if b < 0   # b < 0 just picks last element from each group
      b -= 1 unless b == 0  # b == 0 is same as b == 1, otherwise zero based
      lambda do |element|
        # Element must be inside parent element.
        return false unless element.parent and element.parent.tag?
        index = 0
        siblings = element.parent.children
        siblings = siblings.reverse if reverse
        name = of_type ? element.name : nil
        found = false
        for child in siblings
          # Skip text nodes/comments.
          if child.tag? and (name == nil or child.name == name)
            if a == 0
              # Shortcut when a == 0 no need to go past count
              if index == b
                found = child.equal?(element)
                break
              end
            elsif a < 0
              # Only look for first b elements
              break if index > b
              if child.equal?(element)
                found = (index % a) == 0
                break
              end
            else
              # Otherwise, break if child found and count ==  an+b
              if child.equal?(element)
                found = (index % a) == b
                break
              end
            end
            index += 1
          end
        end
        return found
      end
    end


    def only_child(of_type)
      lambda do |element|
        # Element must be inside parent element.
        return false unless element.parent and element.parent.tag?
        name = of_type ? element.name : nil
        other = false
        for child in element.parent.children
          # Skip text nodes/comments.
          if child.tag? and (name == nil or child.name == name)
            unless child.equal?(element)
              other = true
              break
            end
          end
        end
        return !other
      end
    end


    def next_selector(statement, *values)
      second = Selector.new(statement, *values)
      # If there are alternate selectors, we group them in the top selector.
      if alternates = second.instance_variable_get(:@alternates)
        second.instance_variable_set(:@alternates, nil)
        (@alternates ||= []).concat alternates
      end
      return second
    end

  end


  # See HTML::Selector.new
  def self.selector(statement, *values)
    Selector.new(statement, *values)
  end

end
