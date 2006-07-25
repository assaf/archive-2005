# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require "test/unit"
require File.join(File.dirname(__FILE__), "../lib", "scrapi")


class SelectorTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_element
    html = parse(%Q{<div id="1"></div><p></p><div id="2"></div>})
    # Match element by name.
    match = HTML.selector("div").select(html)
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
    html = parse(%Q{<div id="1"></div><p id="2" title bar="foo"></p><div id="3" title="foo"></div>})
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
  end


  def test_attribute_quoted
    html = parse(%Q{<div id="1" title="foo"></div><div id="2" title="bar"></div>})
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
    html = parse(%Q{<div><p id="1"><span id="2"></span></p></div><div><p id="3"><span id="4"></span></p></div>})
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
  end


  def test_root_selector
    html = parse(%Q{<div id="1"><div id="2"></div></div>})
    match = HTML.selector(":root").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("#1:root").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("#2:root").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_odd_even
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
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
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
    # Test the third child.
    match = HTML.selector("tr:nth-child(0n3)").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Same but an can be omitted when zero.
    match = HTML.selector("tr:nth-child(3)").select(html)
    assert_equal 1, match.size
    assert_equal "3", match[0].attributes["id"]
    # Second element (but not every second element).
    match = HTML.selector("tr:nth-child(0n2)").select(html)
    assert_equal 1, match.size
    assert_equal "2", match[0].attributes["id"]
  end


  def test_nth_child_a_is_one
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
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
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
    # If b is zero, pick the n-th element (here each one).
    match = HTML.selector("tr:nth-child(n0)").select(html)
    assert_equal 4, match.size
    # If b is zero, pick the n-th element (here every second).
    match = HTML.selector("tr:nth-child(2n0)").select(html)
    assert_equal 2, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "3", match[1].attributes["id"]
    # If a and b are both zero, no element selected.
    match = HTML.selector("tr:nth-child(0n0)").select(html)
    assert_equal 0, match.size
    match = HTML.selector("tr:nth-child(0)").select(html)
    assert_equal 0, match.size
  end


  def test_nth_child_a_is_negative
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
    # Since a is -1, picks the first three elements.
    match = HTML.selector("tr:nth-child(-n3)").select(html)
    assert_equal 3, match.size
    assert_equal "1", match[0].attributes["id"]
    assert_equal "2", match[1].attributes["id"]
    assert_equal "3", match[2].attributes["id"]
  end


  def test_nth_child_b_is_negative
    html = parse(%Q{<table><tr id="1"></tr><tr id="2"></tr><tr id="3"></tr><tr id="4"></td></table>})
    match = HTML.selector("tr:nth-child(4n-1)").select(html)
    assert_equal 1, match.size
    assert_equal "4", match[0].attributes["id"]
    match = HTML.selector("tr:nth-child(4n-4)").select(html)
    assert_equal 1, match.size
    assert_equal "1", match[0].attributes["id"]
    match = HTML.selector("tr:nth-child(2n-1)").select(html)
    assert_equal 2, match.size
    assert_equal "2", match[0].attributes["id"]
    assert_equal "4", match[0].attributes["id"]
    match = HTML.selector("tr:nth-child(-2n-1)").select(html)
    assert_equal 0, match.size
  end


protected

  def parse(html)
    return HTML::HTMLParser.parse(html).root
  end

end
