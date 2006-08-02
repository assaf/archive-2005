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


  #
  # Test assert select.
  #

  def test_assert_select
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


  def test_substitution_values
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div#?", /\d+/ do |elements|
      assert_equal 2, elements.size
    end
    assert_select "div" do
      assert_select "div#?", /\d+/ do |elements|
        assert_equal 2, elements.size
        assert_select "#1"
        assert_select "#2"
      end
    end
  end

  
  def test_nested_assert_select
    html_is %Q{<div id="1">foo</div><div id="2">foo</div>}
    assert_select "div" do |elements|
      assert_equal 2, elements.size
      assert_select elements[0], "#1"
      assert_select elements[1], "#2"
    end
    assert_select "div" do
      assert_select "div" do |elements|
        assert_equal 2, elements.size
        # Testing in a group is one thing
        assert_select "#1,#2"
        # Testing individually is another.
        assert_select "#1"
        assert_select "#2"
        assert_select "#3", false
      end
    end
  end


  def test_assert_select_from_rjs
    # With one result.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>\\n<div id=\\"2\\">foo</div>");}
    assert_select "div" do |elements|
      assert elements.size == 2
      assert_select "#1"
      assert_select "#2"
    end
    assert_select "div#?", /\d+/ do |elements|
      assert_select "#1"
      assert_select "#2"
    end
    # With multiple results.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>");\\nElement.update("test2", "<div id=\\"2\\">foo</div>");}
    assert_select "div" do |elements|
      assert elements.size == 2
      assert_select "#1"
      assert_select "#2"
    end
  end


  #
  # Test css_select.
  #


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
    assert_select "div" do
      assert_equal 2, css_select("div").size
      css_select("div").each do |element|
        # Testing as a group is one thing
        assert !css_select("#1,#2").empty?
        # Testing individually is another
        assert !css_select("#1").empty?
        assert !css_select("#2").empty?
      end
    end
  end


  def test_css_select_from_rjs
    # With one result.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>\\n<div id=\\"2\\">foo</div>");}
    assert_equal 2, css_select("div").size
    assert_equal 1, css_select("#1").size
    assert_equal 1, css_select("#2").size
    # With multiple results.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>");\\nElement.update("test2", "<div id=\\"2\\">foo</div>");}
    assert_equal 2, css_select("div").size
    assert_equal 1, css_select("#1").size
    assert_equal 1, css_select("#2").size
  end


  #
  # Test assert_select_rjs.
  #


  def test_assert_select_rjs
    # Simple selection from a single result.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>\\n<div id=\\"2\\">foo</div>");}
    assert_nothing_raised               { assert_select_rjs "test" }
    assert_nothing_raised               { assert_select_rjs "test", "div", 2 }
    assert_raises(AssertionFailedError) { assert_select_rjs "test2" }
    assert_raises(AssertionFailedError) { assert_select_rjs "test2", "div", 2 }
    # Deal with two results.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>");\\nElement.update("test2", "<div id=\\"2\\">foo</div>");}
    assert_nothing_raised               { assert_select_rjs "test", "div", 1 }
    assert_nothing_raised               { assert_select_rjs "test2", "div", 1 }
    assert_raises(AssertionFailedError) { assert_select_rjs "test3" }
  end


  def test_nested_assert_select_rjs
    # Simple selection from a single result.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>\\n<div id=\\"2\\">foo</div>");}
    assert_select_rjs "test" do |elements|
      assert_equal 2, elements.size
      assert_select "#1"
      assert_select "#2"
    end
    # Deal with two results.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>");\\nElement.update("test2", "<div id=\\"2\\">foo</div>");}
    assert_select_rjs "test" do |elements|
      assert_equal 1, elements.size
      assert_select "#1"
    end
    assert_select_rjs "test2" do |elements|
      assert_equal 1, elements.size
      assert_select "#2"
    end
    # Test with assertion and nesting.
    rjs_is %Q{Element.update("test", "<div id=\\"1\\">foo</div>\\n<div id=\\"2\\">foo</div>");}
    assert_select_rjs "test", "div", 2 do |elements|
      assert_equal 2, elements.size
      assert_select "#1"
      assert_select "#2"
    end
  end



protected

  class Response

    def initialize(body)
      @body = body
    end
    
    def headers()
      {}
    end

    def body()
      @body
    end

  end

  class RjsResponse < Response

    def headers()
      {"Content-Type"=>"text/javascript; charset=utf-8"}
    end

  end
      

  def html_is(html)
    @response = Response.new(html)
  end


  def rjs_is(javascript)
    @response = RjsResponse.new(javascript)
  end


  def html_document()
    return HTML::Document.new(@response.body)
  end

end
