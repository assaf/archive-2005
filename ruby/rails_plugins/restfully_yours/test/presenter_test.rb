# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.

require File.dirname(__FILE__) + '/../../../rails/actionpack/test/abstract_unit'
require File.dirname(__FILE__) + '/../../../rails/actionpack/test/active_record_unit'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


class PresenterTopic < ActiveRecord::Base

  class << self
    def find_or_create(title)
      @models ||= {}
      @models[title] ||= PresenterTopic.create(:title=>title)
    end
  end

  set_table_name "topics"

end


class PresenterTopicPresenter < Presenter
  def to_hash(object)
    super.update("url"=>url_for(object))
  end
end


class PresenterTestController < ActionController::Base
  def self.controller_name; "topics"; end
  def self.controller_path; "topics"; end
  self.view_paths = [ File.dirname(__FILE__) + "/fixtures/" ]

  def show()
    topic = PresenterTopic.find(params[:id])
    presenting(topic).render
  end
end


class PresenterTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = PresenterTestController.new

    @model = PresenterTopic.find_or_create('presenting presenters')
    @rewriter = ActionController::UrlRewriter.new(@request, {})
    @presenter = @controller.send(:presenting, @model)
  end

  def test_presenting_controller
    assert @controller == @presenter.controller
  end

  def test_presenting_object
    assert @model == @presenter.object
  end

  def test_presenter_h
    assert_equal '&lt;bracket&gt;', @presenter.send(:h, '<bracket>')
  end

  # TODO: How do we test url_for and named routes?

  def test_render_html
    get :show, :id=>@model.to_param, :format=>'html'
    assert_equal Mime::HTML, @response.content_type
    assert_select '.title', 'presenting presenters'
    assert_select '.content', ''
    assert_select '.created-at[title=?]', /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}-\d{2}:\d{2}/ 
    assert_select '*[id]', false
    assert_select 'a[href=?]', "/topics/show/#{@model.to_param}"
  end

  def test_render_json
    get :show, :id=>@model.to_param, :format=>'json'
    assert_equal Mime::JSON, @response.content_type
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'presenting presenters', json['title']
    assert_nil json['content']
    assert_match /\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2} (-?)\d{4}/, json['created_at']
    assert_nil json['id']
    assert_equal "http://test.host/topics/show/#{@model.to_param}", json['url']
  end

  def test_render_xml
    get :show, :id=>@model.to_param, :format=>'xml'
    assert_equal Mime::XML, @response.content_type
    assert_select 'presenter-topic' do
      assert_select 'title', 'presenting presenters'
      assert_select 'content', ''
      assert_select 'created-at', /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}-\d{2}:\d{2}/
      assert_select 'id', :count=>0
      assert_select 'url', "http://test.host/topics/show/#{@model.to_param}"
    end
  end

  def test_render_html_with_options
    get :using_options, :id=>@model.to_param, :format=>'html'
    assert_select '.title', 'presenting presenters'
    assert_select '*[id=?]', @model.id
    assert_select 'a[href=?]', "/topics/using_options/#{@model.to_param}"
  end

  def test_render_json_with_options
    get :using_options, :id=>@model.to_param, :format=>'json'
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal 'presenting presenters', json['title']
    assert_equal @model.id, json['id']
    assert_equal "http://test.host/topics/using_options/#{@model.to_param}", json['url']
  end

  def test_render_xml_with_options
    get :using_options, :id=>@model.to_param, :format=>'xml'
    assert_select 'presenter-topic' do
      assert_select 'title', 'presenting presenters'
      assert_select 'id', @model.id
      assert_select 'url', "http://test.host/topics/using_options/#{@model.to_param}"
    end
  end
end
