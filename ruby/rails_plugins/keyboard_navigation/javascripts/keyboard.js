// Code originally from jQuery: http://jquery.com/
(OnReady = {
  initialize: function() {
    var browser = navigator.userAgent.toLowerCase()
    if ((/mozilla/.test(browser) && !/compatible/.test(browser)) ||
      /opera/.test(browser)) {
      // Use the handy event callback
      document.addEventListener( "DOMContentLoaded", OnReady.fire, false );
    } else if (/msie/.test(browser) && !/opera/.test(browser)) {
      document.write("<scr" + "ipt id=__ie_init defer=true " + "src=https:///><\/script>");
      var script = document.getElementById("__ie_init");
      script.onreadystatechange = function() {
        if (OnReady.readyState == "complete")
          OnReady.fire();
      };
      script = null;
    } else if (/webkit/.test(browser)) {
      OnReady.safariTimer = setInterval(function() {
        if (document.readyState == "loaded" || document.readyState == "complete") {
          clearInterval( jQuery.safariTimer );
          OnReady.safariTimer = null;
          OnReady.fire();
        }
      }, 10);
    }
    Event.observe(window, 'load', OnReady.fire);
  },

  isReady: false,
  readyList: [],

  register: function(func) {
    // From jQuery.
    if (OnReady.isReady )
      func.apply( document );
    else
      OnReady.readyList.push(func);
    return this;
  },

  fire: function() {
    if (!OnReady.isReady) {
      OnReady.isReady = true;
      if (OnReady.readyList) {
        for (var i = 0, func; func = OnReady.readyList[i]; ++i)
          func.apply(document);
        OnReady.readyList = null;
      }
    }
  }
}).initialize();


var Keyboard = Class.create();

/**
 * Create keyboard shortcuts by initializing Keyboard.Shortcuts
 * with a hash of keycode/handlers.
 *
 * A keycode can be one letter (e.g. "j") or two letters to denote
 * a two-key combination (e.g. "gc" for g followed by c).
 *
 * The handler is called with the current event.
 *
 * For example:
 *   new Keyboard.Shortcuts({
 *     "c": function(event) { alert("c") }
 *   })
 * You can also add keybindings after initialization to the
 * Keyboard.shortcuts.bindings variable.
 */
Keyboard.Shortcuts = Class.create();
Object.extend(Keyboard.Shortcuts.prototype, {
  initialize: function() {
    this.bindings = {};
    Event.observe(document, 'keypress', this.onKeypress.bind(this), true);
    this.prefix = null;
  },

  /**
   * Returns the keycode of the keypress event.
   */ 
  getKeyChar: function(event, modifiers) {
    event = event || window.event;
    modifiers = modifiers || {}
    modifiers.ctrlKey = modifiers.ctrlKey || false;
    modifiers.altKey = modifiers.altKey || false;
    modifiers.metaKey = modifiers.metaKey || false;
    for (var mod in modifiers)
      if (!!modifiers[mod] != !!event[mod])
        return null;
    if (event) {
      var keyCode = event.keyCode || event.which;
      return String.fromCharCode(keyCode).toLowerCase();
    }
    return null;
  },

  /**
   * Handles the keypress event. Ignores the event if it occurrs
   * inside an input control.
   */
  onKeypress: function(event) {
    event = event || window.event;
    var target = Event.element(event);
    if (target.nodeType == 1 && (target.nodeName == "INPUT" ||
        target.nodeName == "TEXTAREA" || target.nodeName == "SELECT"))
      return true;

    var keyCode = this.getKeyChar(event);
    if (this.prefix) {
      var pair = this.prefix + keyCode;
      if (this.bindings[pair] && this.bindings[pair](event)) {
        this.prefix = null;
        Event.stop(event);
        return false;
      }
    }
    if (this.bindings[keyCode] && this.bindings[keyCode](event)) {
      this.prefix = null;
      Event.stop(event);
      return false;
    }
    this.prefix = keyCode;
    return true;
  }
});
Keyboard.shortcuts = new Keyboard.Shortcuts();


/**
 * The keyboard navigator uses keyboard shortcuts to navigate through elements
 * on the page (and between pages) and invoke actions on these elements.
 *
 * For example, a todo list can use the 'j' and 'k' keys to move to the next
 * or previous todo item, 'c' to mark the current item as complete, 'e' to
 * open an in-place editing form, etc.
 *
 * == Usage
 *
 * The navigator implements simple back & forth navigation between any number
 * of elements on the page. The only requirement is that these elements have an
 * ID attribute and that there's an array that provides these elements in order
 * of navigation.
 *
 * The elements are identified by the function select(). The function returns an
 * array of elements. The function is called each time navigation occurs so it
 * can respond to changes made to the page.
 *
 * For convenience, you can also use a selector expression to select multiple
 * elements. For example, {select: ".post"} allows navigation through all elements
 * with the class "post".
 *
 * The navigator installs two keyboard shortcuts for navigating back and forth.
 * The default keyboard shortcuts are 'j' to move forward, and 'k' to move backwards.
 * The application can install additional shortcuts that operate on the currently
 * selected elements. The currently selected element is available from
 * Keyboard.navigator.current.
 *
 * In addition, the navigator selects one element when the page is (re)loaded,
 * and selects an element in response to mouse clicks. If the application needs to
 * do its own navigation, it can call Keyboard.navigator.navigateTo() with a target
 * element and scroll options.
 *
 * The navigator supports pagination using the functions nextPage() and previousPage().
 * When navigating past the last element on the page, the navigator calls nextPage(),
 * and if the function returns a URL, it loads that page. For convenience, you can
 * also use selectors that return a link, e.g. {nextPage: "#paginator .next",
 * previousPage: "#paginator .previous"}.
 *
 * For example:
 *    var navigator = new Keyboard.Navigator({
 *      select: ".post",
 *      nextPage: "#paginator .next",
 *      previousPage: "#paginator .previous",
 *    });
 *
 *    navigator.navigateTo("post-4567");
 *    navigator.navigateTo(Keyboard.Navigator.next);
 *
 *
 * == Marking & Scrolling
 *
 * The navigator visually marks the currently selected elements. Marking the element
 * is done using the marker() method. In addition, when navigating back and forth, to
 * elements that are outside the viewable window, the navigator must scroll the page.
 * Scrolling is done by the scrollTo() method.
 *
 * You can override both methods. You can also configure how these methods (default
 * or yours) behave by passing options to the navigateTo() methods. The default
 * behavior for keyboard navigation is specified with the scrollOptions hash.
 *
 * For example, {scrollOptions: {scroll: true, halfPage: true}} tells the navigator
 * to always scroll the page when navigating to an element outside the visible window.
 * It also tells the navigator to scroll by half a page when moving downwards.
 * The default behavior is {scroll: true}.
 *
 * The marker() function receives an element and set of options. It creates a marker
 * for the currently selected element. The marker use the id "navigator-marker".
 * That id is used to remove the marker when navigating to a different element, and
 * also to style it.
 *
 * The default marker uses &raquo; to display a double right arrow as the first
 * child element of the currently selected element. You can configure the default
 * marker by passing a hash of options instead of a marker function.
 *
 * The option content is a function or string that returns the desired content for
 * the marker. The content is an HTML string, and will be wrapped in a span tag.
 * Alternatively, you can use the option image to use the specified image.
 *
 * The option insertion specifies how the marker is inserted into the selected
 * element. The default insertion is Insertion.Top, placing the marker as the
 * first content part inside the selected element.
 *
 * In cases where the currently selected element is not the right point of
 * insertion, the select option can be used to select a child element. It can
 * be a function, or a selector expression.
 *
 * For example:
 *    new Keyboard.Navigator({
 *      marker: {
 *        select: "h2", // Look for header inside currently selected element
 *        insertion: Insertion.Top,               // Insert at top
 *        image: "http://example.com/marker.gif"  // This image
 *    }});
 *
 * 
 * == Initialization options
 *
 * * select -- Selects all elements that can be navigated to. This can be an array of
 *   elements, a function that returns an array of elements, or a selector expression.
 *   For example, ".post" allows navigation to all elements with the class "post".
 * * keyNext -- Key for moving to the next element/page. By default 'j'.
 * * keyPrevious -- Key for moving to the previous element/page. By default 'k'.
 * * nextPage -- Returns a URL for the next page, when navigating past the last
 *   element on the page. Can be a function, or a selector expression that returns
 *   a link element. For example, "#pagination .next".
 * * previousPage -- Returns a URL for the previous page, when navigating past the
 *   first element on the page. Can be a function, or a selector expression that
 *   returns a link element.
 * * scrollOptions -- Options used when navigating with the keyboard or when
 *   first loading the page. (See below).
 * * marker -- Function or options for creating a marker for the current element.
 *   (See below).
 *
 * The default implementation supports the following scroll options:
 * * scroll -- Scroll the page when navigating to an element that is outside these
 *   viewable window. (True by default)
 * * halfPage -- Scroll half page into the visible window when scrolling the
 *   page upwards.
 *
 * The default implementation supports the following options for marker:
 * * select -- Select an element from the currently selected element. Can be
 *   a function or selector expression. By default uses the currently selected
 *   element.
 *   * content -- The content to insert. May be a string (HTML) or a function
 *     returning HTML. By default uses the &raquo; entity. The content is always
 *     wrapped in a span element with the id navigator-marker.
 *   * image -- Instead of content insert an image with this URL.
 *   * insertion -- Insertion option. The default insertion option is Insertion.Top.
 *     See prototype.js for more insertion options.
 */
Keyboard.Navigator = Class.create();
Object.extend(Keyboard.Navigator, {
  next: {},
  previous: {},
  remove: {},
  markerId: "navigator-marker",
  storeId: "navigator-store"
});
Object.extend(Keyboard.Navigator.prototype, {
  initialize: function(options) {
    this.current = null;

    /* Setup the navigation marker */
    if (typeof options.marker == "function")
      this.marker = options.marker;
    else if (typeof options.marker == "string")
      this.marker = this.createMarker({select: options.marker});
    else
      this.marker = this.createMarker(options.marker || {});

    /* Select all elements we can navigate through */
    if (typeof options.select == "string")
      this.select = this.selector(options.select);
    else if (typeof options.select == "function")
      this.select = options.select;
    else if (options.select.constructor == Array)
      this.select = function() { return options.select; };
    else
      this.select = function() { return []; }

    /* Get next and previous page's URL */
    if (typeof options.nextPage == "string") {
      this.nextPage = function(select) {
        var selector = this.selector(select);
        return function() {
          var list = selector();
          return list[0] ? list[0].href : null;
        }
      }.bind(this)(options.nextPage);
    } else if (typeof options.nextPage == "function")
      this.nextPage = options.nextPage;
    else
      this.nextPage = function() { return null; }

    if (typeof options.previousPage == "string") {
      this.previousPage = function(select) {
        var selector = this.selector(select);
        return function() {
          var list = selector();
          return list[0] ? list[0].href : null;
        }
      }.bind(this)(options.previousPage);
    } else if (typeof options.previousPage == "function")
      this.previousPage = options.previousPage;
    else
      this.previousPage = function() { return null; }

    /* Key bindings and navigation by focus */
    var scrollOptions = {scroll: true, halfPage: true}
    if (options.scrollOptions)
      Object.extend(scrollOptions, options.scrollOptions);
    Keyboard.shortcuts.bindings[options.keyNext || "j"] = function(event) {
      this.navigateTo(Keyboard.Navigator.next, scrollOptions);
    }.bind(this);
    Keyboard.shortcuts.bindings[options.keyPrevious || "k"] = function(event) {
      this.navigateTo(Keyboard.Navigator.previous, scrollOptions);
    }.bind(this);
    Event.observe(document, 'click', function(event) {
      var element = Event.element(event || window.event);
      this.navigateTo(element, {bestMatch:true, blur:false});
      return true;
    }.bind(this));

    /* Position marker when (re)loading page */
    //Event.observe(window, 'load', function() {
    OnReady.register(function() {
      if (this.current)
        this.navigateTo(this.current);
      else if (id = this.getStoredId())
        this.navigateTo(id, scrollOptions);
      if (!this.current) {
        var current = (document.referrer == this.nextPage()) ?
          this.select().last() : this.select().first();
        this.navigateTo(current, scrollOptions);
      }
    }.bind(this));
  },

  next: function(current) {
    var list = this.select();
    for (var i = 0, j = list.length; i < j; ++i)
      if (list[i].id == current.id)
        return list[i + 1];
    return null;
  },

  previous: function(current) {
    var list = this.select();
    for (var i = 0, j = list.length; i < j; ++i)
      if (list[i].id == current.id)
        return list[i - 1];
    return null;
  },

  /**
   * Call this method to navigate to a different element. Target can be an
   * element or identifier.
   *
   * Users can only navigate to elements returned by the select() method
   * (see the select option).
   *
   * If target is Keyboard.Navigator.next, navigates to the next elemenet,
   * or if on the last element of the page, to the next page.
   *
   * If target is Keyboard.Navigator.previous, navigates to the previous
   * elemenet, or if on the first element of the page, to the previous page.
   *
   * If target is Keyboard.Navigator.remove, navigates to the next element
   * following the removed elements, if last, to the previous element.
   * The removed element is specified by the removed option, if null, assumes
   * the current element.
   *
   * The options argument is passed to the focusOn function. The default
   * implementation will them pass it to the marker and scrollTo functions.
   * The default implementation supports the following options:
   * *  scroll -- If true, scroll the page so the selected element is viewed
   *    in full (top part if bigger than screen)
   * *  halfPage -- If true, scroll by at least half page when the next
   *    element navigated to is off screen.
   */
  navigateTo: function(target, options) {
    /* Navigate next/previous */
    if (target == Keyboard.Navigator.next) {
      var next = this.current ? this.next(this.current) : this.select().first();
      if (next)
        return this.navigateTo(next, options);
      next = this.nextPage();
      if (next != null)
        location.href = next;
      return true;
    }
    if (target == Keyboard.Navigator.previous) {
      var previous = this.current ? this.previous(this.current) : this.select().last();
      if (previous)
        return this.navigateTo(previous, options);
      previous = this.previousPage();
      if (previous != null)
        location.href = previous;
      return true;
    }
    /* When removing specified element */
    if (target == Keyboard.Navigator.remove) {
      var removed = $(options.removed || this.current);
      options.removed = null;
      if (removed) {
        var next = this.next(this.current);
        if (!next)
          next = this.previous(this.current);
        return this.navigateTo(next, options);
      }
    }

    /* Best match navigation */
    if (options.bestMatch) {
      var list = this.select();
      for (var i = 0, j = list.length; i < j; ++i)
        if (list[i] == target || Element.childOf(target, list[i])) {
          options.bestMatch = false;
          return this.navigateTo(list[i], options);
        }
      return false;
    }

    /* Lose focus is event happens on an input field */
    if (options.blur !== false) {
      var inputs = document.getElementsByTagName("input");
      for (var i = 0, input; input = inputs[i]; i++)
        input.blur();
    }

    /* Remove existing marker */
    if (this.current) {
      this.focusOff(this.current);
      this.current = null;
      this.setStoredId(null);
    }
    if (!(target = $(target)))
      return false;

    if (target && target.id) {
      this.current = target;
      this.focusOn(target, options);
      this.setStoredId(target.id);
      return true;
    }
    return false;
  },

  /**
   * Override this method if you want to implement different
   * behavior when focusing on an element.
   */
  focusOn: function(element, options) {
    options = options || {};
    this.marker(element, options);
    if (options.scroll)
      this.scrollTo(element, options);
  },

  /**
   * Override this method if you want to implement different
   * behavior when element loses focus.
   */
  focusOff: function(element) {
    if (marker = $(Keyboard.Navigator.markerId))
      marker.remove();
  },

  /**
   * Convenience function for invoking an action by matching a form
   * based on its action URL. The form must be part of the currently
   * selected element.
   *
   * For example:
   *   Keyboard.navigator.invoke(/\/post\/publish/)
   * Submits a form with an action that contains the URL /post/publish.
   */
  invoke: function(action) {
    if (this.current) {
      var forms = this.current.getElementsByTagName("form");
      for (var i = 0; i < forms.length ; ++i) {
        if (forms[i].action && forms[i].action.match(action)) {
          forms[i].onsubmit ?
            forms[i].onsubmit() : forms[i].submit();
          return true;
        }
      }
    }
    return false;
  },

  scrollTo: function(element, options) {
    var focusTop = Position.cumulativeOffset(element)[1];
    var focusBottom = focusTop + Element.getHeight(element);
    var viewTop = window.pageYOffset || document.body.scrollTop || document.documentElement.scrollTop;
    var viewBottom = viewTop + (window.innerHeight || document.documentElement.clientHeight);
    var newTop = viewTop;
    if (focusBottom > viewBottom) {
      newTop += focusBottom - viewBottom;
      var height = window.innerHeight || window.screen.height;
      if (options.halfPage && height)
        newTop += height / 2;
    }
    if (focusTop < newTop)
      newTop = focusTop;
    window.scrollTo(0, newTop);
  },

  getStoredId: function() {
    var element = document.getElementById(Keyboard.Navigator.storeId);
    if (element)
      return element.value;
  },

  setStoredId: function(id) {
    var element = document.getElementById(Keyboard.Navigator.storeId);
    if (element)
      element.value = id;
  },

  selector: function(expression) {
    var selectors = expression.strip().split(/\s+/).map(function(expression) {
      return new Selector(expression);
    });
    return function(scope) {
      return selectors.inject([scope], function(results, selector) {
        return results.map(selector.findElements.bind(selector)).flatten();
      }).flatten();
    }
  },

  createMarker: function(options) {
    var selector;
    if (typeof options.select == "string")
      selector = this.selector(options.select);
    else if (typeof options.select == "function")
      selector = options.select;
    else
      selector = function(element) { return [element]; }

    var content;
    if (options.image) {
      new Image().src = options.image;
      var image = "<img src=\"" + options.image + "\" />";
      content = function() { return image;  }
    } else if (typeof options.content == "string") {
      content = function() {
        var content = options.content;
        return function() { return content; }
      }();
    } else if (typeof options.content == "function")
      content = options.content;
    else
      content = function() { return "&raquo;"; }

    var insertion = options.insertion || Insertion.Top;
    return function(element, options) {
      var marked = selector(element)[0];
      if (marked)
        new insertion(marked, "<span id=\"" + Keyboard.Navigator.markerId + "\">&raquo;</span>");
    }
  }

});
