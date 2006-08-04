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


class AssertSelectController < ActionController::Base

  def response=(html)
    @html = html
  end

  def response(&block)
    @update = block
  end

  def html()
    render :text=>@html, :layout=>false, :content_type=>Mime::HTML
    @html = nil
  end

  def rjs()
    render :update do |page|
      @update.call page
    end
    @update = nil
  end

  def rescue_action(e)
    raise e
  end

end


class AssertSelectTest < Test::Unit::TestCase

  AssertionFailedError = Test::Unit::AssertionFailedError

  def setup
    @controller = AssertSelectController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end


  def teardown
  end


  #
  # Test assert select.
  #

  def test_assert_select
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_select "div", 2
    assert_raises(AssertionFailedError) { assert_select "div", 3 }
    assert_raises(AssertionFailedError){ assert_select "p" }
  end


  def test_equality_true_false
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert_nothing_raised               { assert_select "div" }
    assert_raises(AssertionFailedError) { assert_select "p" }
    assert_nothing_raised               { assert_select "div", true }
    assert_raises(AssertionFailedError) { assert_select "p", true }
    assert_raises(AssertionFailedError) { assert_select "div", false }
    assert_nothing_raised               { assert_select "p", false }
  end


  def test_equality_string_and_regexp
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
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
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
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
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
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
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
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
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>\n<div id=\"2\">foo</div>"
    end
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
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
    end
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
    render_html %Q{<div id="1"></div><div id="2"></div>}
    assert 2, css_select("div").size
    assert 0, css_select("p").size
  end


  def test_nested_css_select
    render_html %Q{<div id="1">foo</div><div id="2">foo</div>}
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
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>\n<div id=\"2\">foo</div>"
    end
    assert_equal 2, css_select("div").size
    assert_equal 1, css_select("#1").size
    assert_equal 1, css_select("#2").size
    # With multiple results.
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
    end
    assert_equal 2, css_select("div").size
    assert_equal 1, css_select("#1").size
    assert_equal 1, css_select("#2").size
  end


  #
  # Test assert_select_rjs.
  #


  def test_assert_select_rjs
    # Test that we can pick up all statements in the result.
    render_rjs do |page|
      page.replace "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
      page.insert_html :top, "test3", "<div id=\"3\">foo</div>"
    end
    found = false
    assert_select_rjs do
      assert_select "#1"
      assert_select "#2"
      assert_select "#3"
      found = true
    end
    assert found
    # Test that we fail if there is nothing to pick.
    render_rjs do |page|
    end
    assert_raises(AssertionFailedError) { assert_select_rjs }
  end


  def test_assert_select_rjs_with_id
    # Test that we can pick up all statements in the result.
    render_rjs do |page|
      page.replace "test1", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
      page.insert_html :top, "test3", "<div id=\"3\">foo</div>"
    end
    assert_select_rjs "test1" do
      assert_select "div", 1
      assert_select "#1"
    end
    assert_select_rjs "test2" do
      assert_select "div", 1
      assert_select "#2"
    end
    assert_select_rjs "test3" do
      assert_select "div", 1
      assert_select "#3"
    end
    assert_raises(AssertionFailedError) { assert_select_rjs "test4" }
  end


  def test_assert_select_rjs_for_replace
    render_rjs do |page|
      page.replace "test1", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
      page.insert_html :top, "test3", "<div id=\"3\">foo</div>"
    end
    # Replace.
    assert_select_rjs :replace do
      assert_select "div", 1
      assert_select "#1"
    end
    assert_select_rjs :replace, "test1" do
      assert_select "div", 1
      assert_select "#1"
    end
    assert_raises(AssertionFailedError) { assert_select_rjs :replace, "test2" }
    # Replace HTML.
    assert_select_rjs :replace_html do
      assert_select "div", 1
      assert_select "#2"
    end
    assert_select_rjs :replace_html, "test2" do
      assert_select "div", 1
      assert_select "#2"
    end
    assert_raises(AssertionFailedError) { assert_select_rjs :replace_html, "test1" }
  end


  def test_assert_select_rjs_for_insert
    render_rjs do |page|
      page.replace "test1", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
      page.insert_html :top, "test3", "<div id=\"3\">foo</div>"
    end
    # Non-positioned.
    assert_select_rjs :insert_html do
      assert_select "div", 1
      assert_select "#3"
    end
    assert_select_rjs :insert_html, "test3" do
      assert_select "div", 1
      assert_select "#3"
    end
    assert_raises(AssertionFailedError) { assert_select_rjs :insert_html, "test1" }
    # Positioned.
    render_rjs do |page|
      page.insert_html :top, "test1", "<div id=\"1\">foo</div>"
      page.insert_html :bottom, "test2", "<div id=\"2\">foo</div>"
      page.insert_html :before, "test3", "<div id=\"3\">foo</div>"
      page.insert_html :after, "test4", "<div id=\"4\">foo</div>"
    end
    assert_select_rjs :insert, :top do
      assert_select "div", 1
      assert_select "#1"
    end
    assert_select_rjs :insert, :bottom do
      assert_select "div", 1
      assert_select "#2"
    end
    assert_select_rjs :insert, :before do
      assert_select "div", 1
      assert_select "#3"
    end
    assert_select_rjs :insert, :after do
      assert_select "div", 1
      assert_select "#4"
    end
    assert_select_rjs :insert_html do
      assert_select "div", 4
    end
  end


  def test_nested_assert_select_rjs
    # Simple selection from a single result.
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>\n<div id=\"2\">foo</div>"
    end
    assert_select_rjs "test" do |elements|
      assert_equal 2, elements.size
      assert_select "#1"
      assert_select "#2"
    end
    # Deal with two results.
    render_rjs do |page|
      page.replace_html "test", "<div id=\"1\">foo</div>"
      page.replace_html "test2", "<div id=\"2\">foo</div>"
    end
    assert_select_rjs "test" do |elements|
      assert_equal 1, elements.size
      assert_select "#1"
    end
    assert_select_rjs "test2" do |elements|
      assert_equal 1, elements.size
      assert_select "#2"
    end
  end


protected

  def render_html(html)
    @controller.response = html
    get :html
  end


  def render_rjs(&block)
    @controller.response &block
    get :rjs
  end

end
