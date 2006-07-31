# assert_select plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


unless defined?(RAILS_ROOT)
 RAILS_ROOT = ENV["RAILS_ROOT"]
end
require File.join(RAILS_ROOT, "test", "test_helper")
require File.join(File.dirname(__FILE__), "..", "init")


class SelectorTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end


  #
  # Basic selector: element, id, class, attributes.
  #

  def test_element
    html = parse(%Q{<div id="1"></div><p></p><div id="2"></div>})
    # Match element by name.
    match = HTML.selector("div").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    # Not case sensitive.
    match = HTML.selector("DIV").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    # Universal match (all elements).
    match = HTML.selector("*").select(html)
    assert_equal 3, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal nil, match[1].attributes["id"]
    assert_equal "2", match[2].attributes["id"]
  end


  def test_identifier
    html = parse(%Q{<div id="1"></div><p></p><div id="2"></div>})
    # Match element by ID.
    match = HTML.selector("div#1").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    # Match element by ID, substitute value.
    match = HTML.selector("div#?", 2).select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Element name does not match ID.
    match = HTML.selector("p#?", 2).select(html)
    assert_equal 0, match.size
    # Use regular expression.
    match = HTML.selector("#?", /\d/).select(html)
    assert_equal 2, match.size
  end


  def test_class_name
    html = parse(%Q{<div id="1" class=" foo "></div><p id="2" class=" foo bar "></p><div id="3" class="bar"></div>})
    # Match element with specified class.
    match = HTML.selector("div.foo").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    # Match any element with specified class.
    match = HTML.selector("*.foo").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    # Match elements with other class.
    match = HTML.selector("*.bar").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # Match only element with both class names.
    match = HTML.selector("*.bar.foo").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
  end


  def test_attribute
    html = parse(%Q{<div id="1"></div><p id="2" title="" bar="foo"></p><div id="3" title="foo"></div>})
    # Match element with attribute.
    match = HTML.selector("div[title]").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Match any element with attribute.
    match = HTML.selector("*[title]").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # Match alement with attribute value.
    match = HTML.selector("*[title=foo]").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Match alement with attribute and attribute value.
    match = HTML.selector("[bar=foo][title]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Not case sensitive.
    match = HTML.selector("[BAR=foo][TiTle]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
  end


  def test_attribute_quoted
    html = parse(%Q{<div id="1" title="foo"></div><div id="2" title="bar"></div><div id="3" title="  bar  "></div>})
    # Match without quotes.
    match = HTML.selector("[title = bar]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Match with single quotes.
    match = HTML.selector("[title = 'bar' ]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Match with double quotes.
    match = HTML.selector("[title = \"bar\" ]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Match with spaces.
    match = HTML.selector("[title = \"  bar  \" ]").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
  end


  def test_attribute_equality
    html = parse(%Q{<div id="1" title="foo bar"></div><div id="2" title="barbaz"></div>})
    # Match (fail) complete value.
    match = HTML.selector("[title=bar]").select(html)
    assert_equal 0, match.size
    # Match space-separate word.
    match = HTML.selector("[title~=foo]").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("[title~=bar]").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    # Match beginning of value.
    match = HTML.selector("[title^=ba]").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Match end of value.
    match = HTML.selector("[title$=ar]").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    # Match text in value.
    match = HTML.selector("[title*=bar]").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    # Match first space separated word.
    match = HTML.selector("[title|=foo]").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("[title|=bar]").select(html)
    assert_equal 0, match.size
  end


  #
  # Selector composition: groups, sibling, children
  #


  def test_selector_group
    html = parse(%Q{<h1 id="1"></h1><h2 id="2"></h2><h3 id="3"></h3>})
    # Simple group selector.
    match = HTML.selector("h1,h3").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    match = HTML.selector("h1 , h3").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # Complex group selector.
    html = parse(%Q{<h1 id="1"><a href="foo"></a></h1><h2 id="2"><a href="bar"></a></h2><h3 id="2"><a href="baz"></a></h3>})
    match = HTML.selector("h1 a, h3 a").select(html)
    assert_equal 2, match.size
    assert_equal "foo", match[0].attributes["href"]
    assert_equal "baz", match[1].attributes["href"]
    # And now for the three selector challange.
    html = parse(%Q{<h1 id="1"><a href="foo"></a></h1><h2 id="2"><a href="bar"></a></h2><h3 id="2"><a href="baz"></a></h3>})
    match = HTML.selector("h1 a, h2 a, h3 a").select(html)
    assert_equal 3, match.size
    assert_equal "foo", match[0].attributes["href"]
    assert_equal "bar", match[1].attributes["href"]
    assert_equal "baz", match[2].attributes["href"]
  end


  def test_sibling_selector
    html = parse(%Q{<h1 id="1"></h1><h2 id="2"></h2><h3 id="3"></h3>})
    # Test next sibling.
    match = HTML.selector("h1+*").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    match = HTML.selector("h1+h2").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    match = HTML.selector("h1+h3").select(html)
    assert_equal 0, match.size
    match = HTML.selector("*+h3").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Test any sibling.
    match = HTML.selector("h1~*").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    match = HTML.selector("h2~*").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
  end


  def test_children_selector
    html = parse(%Q{<div><p id="1"><span id="2"></span></p></div><div><p id="3"><span id="4" class="foo"></span></p></div>})
    # Test child selector.
    match = HTML.selector("div>p").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    match = HTML.selector("div>span").select(html)
    assert_equal 0, match.size
    match = HTML.selector("div>p#3").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    match = HTML.selector("div>p>span").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
    # Test descendant selector.
    match = HTML.selector("div p").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    match = HTML.selector("div span").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
    match = HTML.selector("div *#3").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    match = HTML.selector("div *#4").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
    # This is here because it failed before when whitespaces
    # were not properly stripped.
    match = HTML.selector("div .foo").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
  end


  #
  # Pseudo selectors: root, nth-child, empty, content, etc
  #


  def test_root_selector
    html = parse(%Q{<div id="1"><div id="2"></div></div>})
    # Can only find element if it's root.
    match = HTML.selector(":root").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("#1:root").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("#2:root").select(html)
    assert_equal 0, match.size
    # Opposite for nth-child.
    match = HTML.selector("#1:nth-child(1)").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_odd_even
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test odd nth children.
    match = HTML.selector("tr:nth-child(odd)").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # Test even nth children.
    match = HTML.selector("tr:nth-child(even)").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
  end


  def test_nth_child_a_is_zero
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test the third child.
    match = HTML.selector("tr:nth-child(0n+3)").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Same but an can be omitted when zero.
    match = HTML.selector("tr:nth-child(3)").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Second element (but not every second element).
    match = HTML.selector("tr:nth-child(0n+2)").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Before first and past last returns nothing.:
    assert_raises(ArgumentError) { match = HTML.selector("tr:nth-child(-1)").select(html) }
    match = HTML.selector("tr:nth-child(0)").select(html)
    assert_equal 0, match.size
    match = HTML.selector("tr:nth-child(5)").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_a_is_one
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # a is group of one, pick every element in group.
    match = HTML.selector("tr:nth-child(1n+0)").select(html)
    assert_equal 4, match.size
    # Same but a can be omitted when one.
    match = HTML.selector("tr:nth-child(n+0)").select(html)
    assert_equal 4, match.size
    # Same but b can be omitted when zero.
    match = HTML.selector("tr:nth-child(n)").select(html)
    assert_equal 4, match.size
  end


  def test_nth_child_b_is_zero
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # If b is zero, pick the n-th element (here each one).
    match = HTML.selector("tr:nth-child(n+0)").select(html)
    assert_equal 4, match.size
    # If b is zero, pick the n-th element (here every second).
    match = HTML.selector("tr:nth-child(2n+0)").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # If a and b are both zero, no element selected.
    match = HTML.selector("tr:nth-child(0n+0)").select(html)
    assert_equal 0, match.size
    match = HTML.selector("tr:nth-child(0)").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_a_is_negative
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Since a is -1, picks the first three elements.
    match = HTML.selector("tr:nth-child(-n+3)").select(html)
    assert_equal 3, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    assert_equal "3", match[2].attributes["id"]
    # Since a is -2, picks the first in every second of first four elements.
    match = HTML.selector("tr:nth-child(-2n+3)").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # Since a is -2, picks the first in every second of first three elements.
    match = HTML.selector("tr:nth-child(-2n+2)").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
  end


  def test_nth_child_b_is_negative
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Select last of four.
    match = HTML.selector("tr:nth-child(4n-1)").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
    # Select first of four.
    match = HTML.selector("tr:nth-child(4n-4)").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    # Select last of every second.
    match = HTML.selector("tr:nth-child(2n-1)").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
    # Select nothing since an+b always < 0
    match = HTML.selector("tr:nth-child(-1n-1)").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_substitution_values
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Test with ?n?.
    match = HTML.selector("tr:nth-child(?n?)", 2, 1).select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    match = HTML.selector("tr:nth-child(?n?)", 2, 2).select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
    match = HTML.selector("tr:nth-child(?n?)", 4, 2).select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    # Test with ? (b only).
    match = HTML.selector("tr:nth-child(?)", 3).select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    match = HTML.selector("tr:nth-child(?)", 5).select(html)
    assert_equal 0, match.size
  end


  def test_nth_last_child
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # Last two elements.
    match = HTML.selector("tr:nth-last-child(-n+2)").select(html)
    assert_equal 2, match.size
    assert_equal "3", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
    # All old elements counting from last one.
    match = HTML.selector("tr:nth-last-child(odd)").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
  end


  def test_nth_of_type
    html = parse(%Q{<table><thead></thead><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # First two elements.
    match = HTML.selector("tr:nth-of-type(-n+2)").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    # All old elements counting from last one.
    match = HTML.selector("tr:nth-last-of-type(odd)").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[1].attributes["id"]
  end

  
  def test_first_and_last
    html = parse(%Q{<table><thead></thead><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></tr></table>})
    # First child.
    match = HTML.selector("tr:first-child").select(html)
    assert_equal 0, match.size
    match = HTML.selector(":first-child").select(html)
    assert_equal 1, match.size
    assert_equal "thead", match[0].name
    # First of type.
    match = HTML.selector("tr:first-of-type").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("div:first-of-type").select(html)
    assert_equal 0, match.size
    # Last child.
    match = HTML.selector("tr:last-child").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
    # Last of type.
    match = HTML.selector("tr:last-of-type").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
    match = HTML.selector("thead:last-of-type").select(html)
    assert_equal 1, match.size
    assert_equal "thead", match[0].name
    match = HTML.selector("div:last-of-type").select(html)
    assert_equal 0, match.size
  end


  def test_first_and_last
    # Only child.
    html = parse(%Q{<table><tr></tr></table>})
    match = HTML.selector("table:only-child").select(html)
    assert_equal 0, match.size
    match = HTML.selector("tr:only-child").select(html)
    assert_equal 1, match.size
    assert_equal "tr", match[0].name
    html = parse(%Q{<table><tr></tr><tr></tr></table>})
    match = HTML.selector("tr:only-child").select(html)
    assert_equal 0, match.size
    # Only of type.
    html = parse(%Q{<table><thead></thead><tr></tr><tr></tr></table>})
    match = HTML.selector("thead:only-of-type").select(html)
    assert_equal 1, match.size
    assert_equal "thead", match[0].name
    match = HTML.selector("td:only-of-type").select(html)
    assert_equal 0, match.size
  end


  def test_empty
    html = parse(%Q{<table><tr></tr></table>})
    match = HTML.selector("table:empty").select(html)
    assert_equal 0, match.size
    match = HTML.selector("tr:empty").select(html)
    assert_equal 1, match.size
    html = parse(%Q{<div> </div>})
    match = HTML.selector("div:empty").select(html)
    assert_equal 1, match.size
  end

  
  def test_content
    html = parse(%Q{<div> </div>})
    match = HTML.selector("div:content()").select(html)
    assert_equal 1, match.size
    html = parse(%Q{<div>something </div>})
    match = HTML.selector("div:content()").select(html)
    assert_equal 0, match.size
    match = HTML.selector("div:content(something)").select(html)
    assert_equal 1, match.size
    match = HTML.selector("div:content( 'something' )").select(html)
    assert_equal 1, match.size
    match = HTML.selector("div:content( \"something\" )").select(html)
    assert_equal 1, match.size
    match = HTML.selector("div:content(?)", "something").select(html)
    assert_equal 1, match.size
    match = HTML.selector("div:content(?)", /something/).select(html)
    assert_equal 1, match.size
  end


  #
  # Test negation.
  #


  def test_element_negation
    html = parse(%Q{<p></p><div></div>})
    match = HTML.selector("*").select(html)
    assert_equal 2, match.size
    match = HTML.selector("*:not(p)").select(html)
    assert_equal 1, match.size
    assert_equal "div", match[0].name
    match = HTML.selector("*:not(div)").select(html)
    assert_equal 1, match.size
    assert_equal "p", match[0].name
    match = HTML.selector("*:not(span)").select(html)
    assert_equal 2, match.size
  end


  def test_id_negation
    html = parse(%Q{<p id="1"></p><p id="2"></p>})
    match = HTML.selector("p").select(html)
    assert_equal 2, match.size
    match = HTML.selector(":not(#1)").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    match = HTML.selector(":not(#2)").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
  end


  def test_class_name_negation
    html = parse(%Q{<p class="foo"></p><p class="bar"></p>})
    match = HTML.selector("p").select(html)
    assert_equal 2, match.size
    match = HTML.selector(":not(.foo)").select(html)
    assert_equal 1, match.size
    assert_equal "bar", match[0].attributes["class"]
    match = HTML.selector(":not(.bar)").select(html)
    assert_equal 1, match.size
    assert_equal "foo", match[0].attributes["class"]
  end


  def test_attribute_negation
    html = parse(%Q{<p title="foo"></p><p title="bar"></p>})
    match = HTML.selector("p").select(html)
    assert_equal 2, match.size
    match = HTML.selector(":not([title=foo])").select(html)
    assert_equal 1, match.size
    assert_equal "bar", match[0].attributes["title"]
    match = HTML.selector(":not([title=bar])").select(html)
    assert_equal 1, match.size
    assert_equal "foo", match[0].attributes["title"]
  end

  
  def test_pseudo_class_negation
    html = parse(%Q{<div><p id="1"></p><p id="2"></p></div>})
    match = HTML.selector("p").select(html)
    assert_equal 2, match.size
    match = HTML.selector("p:not(:first-child)").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
    match = HTML.selector("p:not(:nth-child(2))").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
  end
  

  def test_negation_details
    html = parse(%Q{<p id="1"></p><p id="2"></p>})
    assert_raises(ArgumentError) { match = HTML.selector(":not(").select(html) }
    assert_raises(ArgumentError) { match = HTML.selector(":not(:not())").select(html) }
  end


  def test_select_from_element
    html = parse(%Q{<div><p id="1"></p><p id="2"></p></div>})
    match = HTML.selector("div").select(html)[0]
    match = match.select("p")
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
  end


protected

  def parse(html)
    return HTML::Document.new(html).root
  end

end
