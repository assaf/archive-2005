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


class AssertSelectTest < Test::Unit::TestCase

  AssertionFailedError = Test::Unit::AssertionFailedError

  def setup
    @html = nil
  end

  def teardown
  end


  def test_assertion
    html_is %Q{<div id="1"></div><div id="2"></div>}
    assert_select "div", 2
    assert_raises(AssertionFailedError) { assert_select "div", 3 }
    assert_raises(AssertionFailedError){ assert_select "p" }
  end


  def test_equality_true_false
    html_is %Q{<div id="1"></div><div id="2"></div>}
    assert_nothing_raised               { assert_select "div" }
    assert_raises(AssertionFailedError) { assert_select "p" }
    assert_nothing_raised               { assert_select "div", true }
    assert_raises(AssertionFailedError) { assert_select "p", true }
    assert_raises(AssertionFailedError) { assert_select "div", false }
    assert_nothing_raised               { assert_select "p", false }
  end


  def test_equality_string_and_regexp
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised               { assert_select "div", "foo" }
    assert_raises(AssertionFailedError) { assert_select "div", "bar" }
    assert_nothing_raised               { assert_select "div", :text=>"foo" }
    assert_raises(AssertionFailedError) { assert_select "div", :text=>"bar" }
    assert_nothing_raised               { assert_select "div", /(foo|bar)/ }
    assert_raises(AssertionFailedError) { assert_select "div", /foobar/ }
    assert_nothing_raised               { assert_select "div", :text=>/(foo|bar)/ }
    assert_raises(AssertionFailedError) { assert_select "div", :text=>/foobar/ }
    assert_raises(AssertionFailedError) { assert_select "p", :text=>/foobar/ }
  end


  def test_equality_of_instances
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_nothing_raised               { assert_select "div", 2 }
    assert_raises(AssertionFailedError) { assert_select "div", 3 }
    assert_nothing_raised               { assert_select "div", 1..2 }
    assert_raises(AssertionFailedError) { assert_select "div", 3..4 }
    assert_nothing_raised               { assert_select "div", :count=>2 }
    assert_raises(AssertionFailedError) { assert_select "div", :count=>3 }
    assert_nothing_raised               { assert_select "div", :minimum=>1 }
    assert_nothing_raised               { assert_select "div", :minimum=>2 }
    assert_raises(AssertionFailedError) { assert_select "div", :minimum=>3 }
    assert_nothing_raised               { assert_select "div", :maximum=>2 }
    assert_nothing_raised               { assert_select "div", :maximum=>3 }
    assert_raises(AssertionFailedError) { assert_select "div", :maximum=>1 }
    assert_nothing_raised               { assert_select "div", :minimum=>1, :maximum=>2 }
    assert_raises(AssertionFailedError) { assert_select "div", :minimum=>3, :maximum=>4 }
  end


  def test_nested_assertion
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div" do |elements|
      assert_equal 2, elements.size
      assert_select elements[0], "#1"
      assert_select elements[1], "#2"
    end
    to_select = ["1", "2"]
    assert_select "div" do
      assert_select "div" do |elements|
        assert_equal 1, elements.size
        assert_select "#1,#2"
        assert_select "#3", false
        assert to_select.delete(elements[0].attributes["id"])
      end
    end
    assert to_select.empty?
  end


  def test_substitution_values
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div#?", /\d+/ do |elements|
      assert_equal 2, elements.size
    end
    to_select = ["1", "2"]
    assert_select "div" do
      assert_select "div#?", /\d+/ do |elements|
        assert_equal 1, elements.size
        assert_select "#1,#2"
        assert to_select.delete(elements[0].attributes["id"])
      end
    end
    assert to_select.empty?
  end


  def test_css_select
    html_is %Q{<div id="1"></div><div id="2"></div>}
    assert 2, css_select("div").size
    assert 0, css_select("p").size
  end


  def test_nested_css_select
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div#?", /\d+/ do |elements|
      assert_equal 1, css_select(elements[0], "div").size
      assert_equal 1, css_select(elements[1], "div").size
    end
    to_select = ["1", "2"]
    assert_select "div" do
      assert_equal 2, css_select("div").size
      css_select("div").each do |element|
        assert !css_select("#1,#2").empty?
        assert to_select.delete(element.attributes["id"])
      end
    end
    assert to_select.empty?
  end


protected

  def html_is(html)
    @html = html
  end

  def html_document()
    return HTML::Document.new(@html)
  end

end
