# Keyboard shortcuts/navigation helper plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


module KeyboardHelper

    @@navigator_cookie = "navigator"

    # Defines a keyboard shortcut. The first element specifies the key,
    # or two key combination. The second element provides the body of
    # the handler function. The keypress event is passed in the argument
    # +event+. 
    #
    # For example:
    #   update_page_tag do |page|
    #     page.shortcut "x", "alert(event)"
    #   end
    def shortcut(key, script = nil)
        self << "Keyboard.shortcuts.bindings[#{key.to_json}]=function(event){"
        if block_given?
            yield self
        else
            self << script
        end
        self << "};"
    end


    # Returns a +script+ tag to initialize keyboard navigation. Place this
    # at the header of the page to enable keyboard navigation.
    #
    # The following sections describe the options you can use with this
    # method. The only required option is +:select+.
    #
    # == Selecting elements
    #
    # The +:select+ option identifies the elements used for navigation.
    # Back and forth navigation depends on the order of these elements.
    #
    # This option can be an array of elements. However, there is no way to
    # change the array when elements are added/removed using JavaScript.
    # Instead, use a function that returns an array of elements. For example:
    #    
    #   <%= navigator :select=>Proc.new {
    #          %Q{ return document.getElementByClassName("posts"); }
    #       }
    #   %>
    #
    # As a convenience, the option can also be a selector expression,
    # e.g. ".post" will select all elements with the class "post".
    # The selector will update the array when elements are added/removed,
    # but may be slower than an equivalent function.
    #
    # === Back & forth keys
    #
    # The navigator installs two keyboard shortcuts for navigating to
    # the next and previous element. The default keyboard shortcuts are
    # 'j' to move forward, and 'k' to move backwards.
    #
    # You can select different keys using the :key_next and :key_previous
    # options.
    #
    # Use #shortcut to install additional keyboard shortcuts that operate
    # on the current element, for example:
    #   page.shortcut "r" do
    #     page << "Keyboard.navigator.invoke(/\/post\/remove/);"
    #     page << "return true"
    #   end
    #
    # == Pagination
    #
    # The navigator supports pagination. When navigating past the last
    # element on the page, it uses the URL of the next page to navigate
    # to the first element on that page. When navigating past the first
    # element on the page, it uses the URL of the previous page to
    # navigate to the last element on that page.
    #
    # The option +:next_page+ is a selector expression that returns a link
    # element which links to the next page. Similarly, +:previous_page+ is
    # a selector for the link to the previous page. For example:
    #   :next_page=>"#pagination .next", :previous_page=>"#pagination .previous"
    #
    # == The marker
    #
    # The current element is identified by a marker. The marker is an element
    # with the id "navigator-marker" that is added to the current element, and
    # removed when shifting the focus.
    #
    # You can use a Ruby proc to create a function for the +:marker: option.
    # The function is called with the current element and the options passed
    # to the #navigate_to method.
    #
    # For convenience, you can configure the built-in implementation with a
    # Hash of options:
    # * <tt>:content</tt> -- Specifies the HTML content of the marker.
    # * <tt>:image</tt> -- Specifies the URL of an image to use.
    # * <tt>:insertion<tt> -- Specifies an insertion option (see prototype.js).
    # * <tt>:select</tt> -- Selects a child element of the current element
    #   on which to perform insertion.
    #
    # The default marker is equivalent to:
    #   :marker=>{
    #     :content=>"&raquo;",
    #     :insertion="Insertion.Top".to_sym,
    #     :select=>Proc.new { "return arguments[0]" }
    #   }
    #
    # If you need more than that, replace the +focusOn+ and +focusOff+ functions
    # of the +Keyboard.navigator+ object.
    #
    # == Scroll options
    #
    # You can specify scroll options when navigating to an element using
    # #navigate_to. To specify how the default keyboard shortcuts operate, pass
    # these options to the :scroll_options option.
    #
    # The default options are equivalent to:
    #   :scroll_options=>{ :scroll=>true, :half_page=>true }
    #
    # The default implementation of the +focusOn+ function supports these
    # two options:
    # * <tt>:scroll</tt> -- Scroll the page so the current element, or at least
    #   the top part is within the viewing area.
    # * <tt>:half_page</tt> -- When navigating forward and scrolling upwards,
    #   scroll by half a page.
    #
    # == Example
    #
    #   <%= navigator :select=>Proc.new {
    #          %Q{ return document.getElementByClassName("posts"); }
    #       },
    #       :next_page=>"#pagination .next", :previous_page=>"#pagination .previous",
    #       :marker=>{:image=>image_path("marker.gif")},
    #       :scroll_options=>{:scroll=>true, :half_page=>true}
    #   %>
    def navigator(options)
        @@navigator_cookie = options[:cookie]
        javascript_tag "if (!Keyboard.navigator) Keyboard.navigator = new Keyboard.Navigator(#{options_for_navigator(options)});"
    end


    # Navigates to the specified element.
    #
    # The first argument identifies the element. It can be one of the following:
    # * <tt>String</tt> -- Navigate to the element with this identifier.
    # * <tt>nil</tt> -- Remove focus from the currently selected element.
    # * <tt>:next</tt> -- Navigate to the next element, if on the last element on
    #   the page, to the next page.
    # * <tt>:previous</tt> -- Navigate to the previous element, if on the first
    #   element on the page, to the previous page.
    # * <tt>:remove</tt> -- Navigate away from the element being removed. Navigates
    #   to the next element, or if the last element on the page, to the previous
    #   element.
    #
    # You can pass options that affect navigation, e.g. scrolling the selected
    # element into view, highlighting the selected element, etc. The supported
    # options depend on the implementation of the +focusOn+ function.
    #
    # The default implementation supports the following options:
    # * <tt>:scroll</tt> -- Scroll the page so the current element, or at least
    #   the top part is within the viewing area.
    # * <tt>:half_page</tt> -- When navigating forward and scrolling upwards,
    #   scroll by half a page.
    #
    # You can call this function from an RJS template, for example:
    #   update_page do |page|
    #     page.navigate_to "post-123", :scroll=>true, :half_page=>true
    #   end
    #
    # You can also use this function without rendering anything. For example,
    # in response to a form action you may redirect the user and navigate to
    # a specific element, or reset navigation to the first element on the page.
    #
    # With this option you can use a string to identify the element or +nil+
    # to reset the current element. This method must be called before #render or
    # #redirect_to since it changes the navigation cookie.
    #
    # For example:
    #   navigate_to
    #   redirect_to :back
    def navigate_to(id = nil, options = nil)
        element, id = case id
            when :next: ["Keyboard.Navigator.next", nil]
            when :previous: ["Keyboard.Navigator.previous", nil]
            when :remove: ["Keyboard.Navigator.remove", nil]
            else [id.to_json, id]
        end
        if self.is_a?(ActionView::Helpers::PrototypeHelper::JavaScriptGenerator)
            options = options ? @context.send(:options_for_navigator, options) : "null"
            record "Keyboard.navigator.navigateTo(#{element},#{options});"
        else
            case id
                when String: cookies[@@navigator_cookie || "navigator"] = {:value=>id}
                when nil: cookies.delete "navigator"
            end
        end
    end


private

    # Method to perform fancy transformation of Ruby hashes to JavaScript options.
    #
    # * Names are camelized sans first letter, so :next_page becomes "nextPage".
    # * Procs are called to return the body of a function which is then wrapped
    #   in <tt>function(){...}</tt>.
    # * Symbols are passed as is, e.g. :window is passed as <tt>window</tt>.
    # * Hashes are processed recursively.
    # * All other values are converted to their JSON equivalent.
    #
    # For example:
    #   options_for_navigator :nothing=>nil,
    #     :string=>"xyz",
    #     :return_true=>Proc.new { "return true" },
    #     :event=>"window.event".to_sym,
    #     :hash=>{:foo=>:bar}
    #   }
    # Produces:
    #   {nothing: null,
    #    string: "xyz",
    #    returnTrue:function(){ return true },
    #    event: window.event,
    #    hash: { foo: bar }
    #   }
    def options_for_navigator(options)
        js_options = options.inject({}) do |map, pair|
            name, value = *pair
            map[name.to_s.camelize(:lower)] = case value
                when Hash: options_for_navigator(value)
                when Proc: "function(){#{value.call}}"
                when Symbol: value.to_s
                else value.to_json
            end
            map
        end
        options_for_javascript(js_options)
    end

end


