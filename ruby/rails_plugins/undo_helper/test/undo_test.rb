unless defined?(RAILS_ROOT)
  RAILS_ROOT = ENV["RAILS_ROOT"] ||
    File.join(File.dirname(__FILE__), "../../../../")
end
require File.join(RAILS_ROOT, "test", "test_helper")
require File.join(File.dirname(__FILE__), "..", "init")

# Re-raise errors caught by the controller.
class TestController < ActionController::Base ; def rescue_action(e) raise e end; end

class UndoTest < Test::Unit::TestCase

  include UndoHelper

  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end


  def test_undo_method
    assert_kind_of Undo, undo
  end


  def test_push_new_action
    assert_equal "", render("undo.render")
    request = {:controller=>"foo", :action=>"bar"}
    @controller.undo.push "Undo title", request
    assert_equal %Q{<form action="/foo/bar?undo=true" class="button" method="post" onsubmit="new Ajax.Request('/foo/bar?undo=true', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input name="commit" title="Undo title" type="submit" value="Undo" /></form>}, render("undo.render")
    @controller.undo.pop request.merge(:undo=>"true")
    assert_equal "", render("undo.render")
  end


  def test_set_button_and_class
    assert_equal "", render("undo.render")
    @controller.undo.push "Undo title", :controller=>"foo", :action=>"bar"
    assert_equal %Q{<form action="/foo/bar?undo=true" class="fc" method="post" onsubmit="new Ajax.Request('/foo/bar?undo=true', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input class="sc" name="commit" title="Undo title" type="submit" value="Button" /></form>},
                 render(%Q{undo.render("Button", :form=>{:class=>"fc"}, :button=>{:class=>"sc"})})
  end


  def test_disabled_button
    assert_equal "", render("undo.render")
    assert_equal %Q{<form action="" class="fc" method="post" onsubmit="new Ajax.Request('', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input class="sc" disabled="disabled" name="commit" type="submit" value="Button" /></form>},
                 render(%Q{undo.render("Button", :form=>{:class=>"fc"}, :disabled=>{:class=>"sc"})})
  end


  def test_multilevel_undo
    Undo.levels = 2
    assert_equal 2, Undo.levels
    assert_equal "", render("undo.render")
    request1 = {:controller=>"foo", :action=>"bar1"}
    @controller.undo.push "Undo title", request1
    assert_equal %Q{<form action="/foo/bar1?undo=true" class="button" method="post" onsubmit="new Ajax.Request('/foo/bar1?undo=true', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input name="commit" title="Undo title" type="submit" value="Undo" /></form>}, render("undo.render")
    request2 = {:controller=>"foo", :action=>"bar2"}
    @controller.undo.push "Undo title", request2
    assert_equal %Q{<form action="/foo/bar2?undo=true" class="button" method="post" onsubmit="new Ajax.Request('/foo/bar2?undo=true', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input name="commit" title="Undo title" type="submit" value="Undo" /></form>}, render("undo.render")
    @controller.undo.pop request2.merge(:undo=>"true")
    assert_equal %Q{<form action="/foo/bar1?undo=true" class="button" method="post" onsubmit="new Ajax.Request('/foo/bar1?undo=true', {asynchronous:true, evalScripts:true, parameters:Form.serialize(this)}); return false;"><input name="commit" title="Undo title" type="submit" value="Undo" /></form>}, render("undo.render")
    @controller.undo.pop request1.merge(:undo=>"true")
    assert_equal "", render("undo.render")
  end


  def render(code)
    @controller.class.send :define_method, :index do
      render :inline=>"<%= #{code} %>"
    end
    get :index
    return @response.body
  end

end
