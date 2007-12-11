# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.

require File.dirname(__FILE__) + '/../../../rails/actionpack/test/abstract_unit'
require File.dirname(__FILE__) + '/../../../rails/actionpack/test/active_record_unit'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


class IfModifiedReply < ActiveRecord::Base
  set_table_name "replies"
end

class IfModifiedTopic < ActiveRecord::Base

  class << self
    def find_or_create(title)
      @models ||= {}
      @models[title] ||= IfModifiedTopic.create(title)
    end
  end

  set_table_name "topics"
  has_many :replies, :class_name=>"IfModifiedReply", :foreign_key=>"topic_id"

  def initialize(title)
    super()
    self.title = title
    self.content = ""
    self.updated_at = Time.now
  end

  def record_timestamps()
    # Either that or sleep for a second during update!(true)
    false
  end

  def update!(delay = false)
    replies.create :content=>"Reply #{replies.count}"
    self.updated_at += 1 if delay
    save!
  end

end


class IfModifiedController < ActionController::Base
  def show()
    topic = IfModifiedTopic.find_or_create('model')
    if_modified topic do
      render :text=>rand # Prevent Rails ETag
    end
  end

  def update()
    topic = IfModifiedTopic.find_or_create('model')
    if_unmodified topic do
      topic.update!
      render :text=>rand # Prevent Rails ETag
    end
  end

  def show_empty()
    if_modified nil do
      render :text=>rand # Prevent Rails ETag
    end
  end

  def update_empty()
    if_unmodified nil do
      render :text=>rand # Prevent Rails ETag
    end
  end

  def show_array()
    topics = ['model', 'model2'].map { |name| IfModifiedTopic.find_or_create(name) }
    if_modified topics do
      render :text=>rand # Prevent Rails ETag
    end
  end

  def update_array()
    topics = ['model', 'model2'].map { |name| IfModifiedTopic.find_or_create(name) }
    if_unmodified topics do
      topics.first.update!
      render :text=>rand # Prevent Rails ETag
    end
  end

  def create()
    render :status=>:created, :text=>rand
    modified IfModifiedTopic.find_or_create('model')
  end

  def redirect()
    redirect_to "elsewhere"
  end

  def show_naked()
    if_modified Object.new do
      render :text=>"naked"
    end
  end

  def update_naked()
    if_unmodified Object.new do
      render :text=>"naked"
    end
  end

  def etag
    self.etag = 'magical'
    render :nothing=>true
  end

  def last_modified
    self.last_modified = Time.now
    render :nothing=>true
  end

  def on_condition
    if conditional(:etag=>'magical', :last_modified=>Time.now - 1.minute)
      render :nothing=>true
    else
      head :not_modified
    end
  end

  def rescue_action(e) raise end
end


class IfModifiedTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = IfModifiedController.new

    @request.host = "example.com"
    @model = IfModifiedTopic.find_or_create('model')
  end

  def assert_cache_control()
    case @response.response_code
    when 200, 201
      assert @response.headers['Last-Modified'] =~ /[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT/ || @response.headers['Last-Modified'].blank?
      assert @response.headers['ETag'] =~ /[0-9a-f]{32}/ || @response.headers['ETag'].blank?
      caching = @response.headers['Cache-Control'].split(/,\s*/)
      assert !caching.include?('no-cache')
      assert caching.include?('must-revalidate')
      assert caching.include?('private')
      assert caching.include?('max-age=0')
    when 304
      # Required by HTTP 1.1
      assert @response.headers['ETag'] =~ /[0-9a-f]{32}/ || @response.headers['ETag'].blank?
      # Same as before
      assert_nil @response.headers['Last-Modified']
      assert_nil @response.headers['Cache-Control']
    else
      # None of these is relevant.
      assert_nil @response.headers['Last-Modified']
      assert_nil @response.headers['ETag']
      assert @response.headers['Cache-Control']['no-cache']
    end
  end

  def get_with_headers(action, options = {})
    @request    = ActionController::TestRequest.new
    etags = options[:etags] || @response.headers['ETag'] unless options[:etags] == false
    @request.env['HTTP_IF_NONE_MATCH'] = Array(etags).join(', ') unless etags.blank?
    last_modified = options[:last_modified] || @response.headers['Last-Modified'] unless options[:last_modified] == false
    if last_modified 
      last_modified = last_modified.httpdate if Time === last_modified
      @request.env['HTTP_IF_MODIFIED_SINCE'] = last_modified
    end
    @response   = ActionController::TestResponse.new
    @controller = IfModifiedController.new
    get action
    assert_cache_control
  end

  def put_with_headers(action, options = {})
    @request = ActionController::TestRequest.new
    etags = options[:etags] || @response.headers['ETag'] unless options[:etags] == false
    @request.env['HTTP_IF_MATCH'] = Array(etags).join(', ') unless etags.blank?
    last_modified = options[:last_modified] || @response.headers['Last-Modified'] unless options[:last_modified] == false
    if last_modified 
      last_modified = last_modified.httpdate if Time === last_modified
      @request.env['HTTP_IF_UNMODIFIED_SINCE'] = last_modified
    end
    @response = ActionController::TestResponse.new
    put action
    assert_cache_control
  end


  def test_if_modified
    get :show
    assert_response :ok
    get :show
    assert_response :ok
    assert_cache_control
  end

  def test_if_modified_since_no_update
    get :show
    assert_response :ok
    get_with_headers :show, :etags=>false
    assert_response :not_modified
  end

  def test_if_modified_since_fast_update
    get :show
    assert_response :ok
    @model.update! false
    get_with_headers :show, :etags=>false
    assert_response :not_modified
  end

  def test_if_modified_since_slow_update
    get :show
    assert_response :ok
    get_with_headers :show, :etags=>false
    @model.update! true
    get_with_headers :show, :etags=>false
    assert_response :ok
    get_with_headers :show, :etags=>false
    assert_response :not_modified
  end

  def test_if_none_match_no_update
    get :show
    assert_response :ok
    get_with_headers :show, :last_modified=>false
    assert_response :not_modified
    get_with_headers :show, :last_modified=>false
    assert_response :not_modified
  end

  def test_if_none_match_fast_update
    get :show
    assert_response :ok
    @model.update! false
    get_with_headers :show, :last_modified=>false
    assert_response :ok
    get_with_headers :show, :last_modified=>false
    assert_response :not_modified
  end

  def test_if_none_match_slow_update
    get :show
    assert_response :ok
    @model.update! true
    get_with_headers :show, :last_modified=>false
    assert_response :ok
    get_with_headers :show, :last_modified=>false
    assert_response :not_modified
  end

  def test_if_modified_since_and_none_match_no_update
    get :show
    assert_response :ok
    get_with_headers :show
    assert_response :not_modified
    get_with_headers :show
    assert_response :not_modified
  end

  def test_if_modified_since_and_none_match_update
    get :show
    assert_response :ok
    @model.update! false
    get_with_headers :show
    assert_response :ok
    get_with_headers :show
    assert_response :not_modified
  end

  def test_if_modified_no_data
    get :show_empty
    assert_response :ok
    get_with_headers :show_empty
    assert_response :not_modified
  end

  def test_if_none_match_no_data
    get :show_empty
    assert_response :ok
    get_with_headers :show_empty, :last_modified=>false
    assert_response :not_modified
    get_with_headers :show_empty, :last_modified=>false
    assert_response :not_modified
  end

  def test_if_modified_since_and_none_match_no_data
    get :show_empty
    assert_response :ok
    get_with_headers :show_empty
    assert_response :not_modified
    get_with_headers :show_empty
    assert_response :not_modified
  end

  def test_if_modified_array
    get :show_array
    assert_response :ok
    get_with_headers :show_array
    assert_response :not_modified
  end

  def test_if_modified_since_array
    get :show_array
    assert_response :ok
    get_with_headers :show_array, :etags=>false
    assert_response :not_modified
    get :show_array
    @model.update! true
    get_with_headers :show_array, :etags=>false
    assert_response :ok
  end

  def test_if_none_match_array
    get :show_array
    assert_response :ok
    get_with_headers :show_array, :last_modified=>false
    assert_response :not_modified
    get_with_headers :show_array, :last_modified=>false
    assert_response :not_modified
    @model.update! false
    get_with_headers :show_array, :last_modified=>false
    assert_response :ok
  end

  def test_if_modified_since_and_none_match_array
    get :show_array
    assert_response :ok
    get_with_headers :show_array
    assert_response :not_modified
    get_with_headers :show_array
    assert_response :not_modified
  end

  def test_if_unmodified
    put :update
    assert_response :ok
    put :update
    assert_response :ok
    assert_cache_control
  end

  def test_if_unmodified_since_no_update
    get :show
    assert_response :ok
    put_with_headers :update, :etags=>false
    assert_response :ok
    put_with_headers :update, :etags=>false
    assert_response :ok
  end

  def test_if_unmodified_since_fast_update
    get :show
    assert_response :ok
    @model.update! false
    put_with_headers :update, :etags=>false
    assert_response :ok
  end

  def test_if_unmodified_since_slow_update
    get :show
    assert_response :ok
    @model.update! true
    put_with_headers :update, :etags=>false
    assert_response :precondition_failed
  end

  def test_if_match_no_update
    get :show
    assert_response :ok
    put_with_headers :update, :last_modified=>false
    assert_response :ok
    put_with_headers :update, :last_modified=>false
    assert_response :ok
  end

  def test_if_match_fast_update
    get :show
    assert_response :ok
    @model.update! false
    put_with_headers :update, :last_modified=>false
    assert_response :precondition_failed
  end

  def test_if_match_slow_update
    get :show
    assert_response :ok
    @model.update! true
    put_with_headers :update, :last_modified=>false
    assert_response :precondition_failed
  end

  def test_if_unmodified_since_and_match_no_update
    get :show
    assert_response :ok
    put_with_headers :update
    assert_response :ok
    put_with_headers :update
    assert_response :ok
  end

  def test_if_unmodified_since_and_match_update
    get :show
    assert_response :ok
    @model.update! false
    put_with_headers :update
    assert_response :precondition_failed
  end

  def test_if_unmodified_no_data
    get :show_empty
    assert_response :ok
    put_with_headers :update_empty
    assert_response :ok
  end

  def test_if_unmodified_since_no_data
    get :show_empty
    assert_response :ok
    put_with_headers :update_empty, :etags=>false
    assert_response :ok
    put_with_headers :update_empty, :etags=>false
    assert_response :ok
  end

  def test_if__match_no_data
    get :show_empty
    assert_response :ok
    put_with_headers :update_empty, :last_modified=>false
    assert_response :ok
    put_with_headers :update_empty, :last_modified=>false
    assert_response :ok
  end

  def test_if_unmodified_since_and_match_no_data
    get :show_empty
    assert_response :ok
    put_with_headers :update_empty
    assert_response :ok
    put_with_headers :update_empty
    assert_response :ok
  end

  def test_if_unmodified_array
    get :show_array
    assert_response :ok
    put_with_headers :update_array
    assert_response :ok
  end

  def test_if_unmodified_since_array
    get :show_array
    assert_response :ok
    put_with_headers :update_array, :etags=>false
    assert_response :ok
    put_with_headers :update_array, :etags=>false
    assert_response :ok
    @model.update! 1.second
    put_with_headers :update_array, :etags=>false
    assert_response :precondition_failed
  end

  def test_if_match_array
    get :show_array
    assert_response :ok
    put_with_headers :update_array, :last_modified=>false
    assert_response :ok
    put_with_headers :update_array, :last_modified=>false
    assert_response :ok
    @model.update! 0.second
    put_with_headers :update_array, :last_modified=>false
    assert_response :precondition_failed
  end

  def test_if_unmodified_since_and_match_array
    get :show_array
    assert_response :ok
    put_with_headers :update_array
    assert_response :ok
    put_with_headers :update_array
    assert_response :ok
  end

  def test_if_modified_naked
    get :show_naked
    assert_response :ok
    assert @response.headers['Last-Modified'].blank?
    assert @response.headers['ETag'][/("?)(.*)\1/, 2].blank?
    get_with_headers :show_naked
    assert_response :ok
  end

  def test_if_unmodified_naked
    get :show_naked
    assert_response :ok
    assert @response.headers['Last-Modified'].blank?
    assert @response.headers['ETag'][/("?)(.*)\1/, 2].blank?
    put_with_headers :update_naked
    assert_response :ok
  end

  def test_201_includes_etag_and_last_modified
    post :create
    assert_response :created
    assert_cache_control
  end

  def test_302_includes_etag_and_last_modified
    post :redirect
    assert_response :found
    assert_cache_control
  end

  def test_two_representations_do_not_conflict
    request = lambda do |format|
      @response = ActionController::TestResponse.new
      @request.format = format
      get :show
      @request  = ActionController::TestRequest.new
    end

    request.call Mime::XML
    xml = @response.headers['ETag']
    request.call Mime::JSON
    json = @response.headers['ETag']

    @request.env['HTTP_IF_NONE_MATCH'] = xml
    request.call Mime::XML
    assert_response :not_modified
    @request.env['HTTP_IF_NONE_MATCH'] = xml
    request.call Mime::JSON
    assert_response :ok
    
    @request.env['HTTP_IF_NONE_MATCH'] = json
    request.call Mime::XML
    assert_response :ok
    @request.env['HTTP_IF_NONE_MATCH'] = json
    request.call Mime::JSON
    assert_response :not_modified
  end

  def test_etag_setter
    get :etag
    assert @response.headers['ETag'] == %{"magical"}
  end

  def test_last_modified_setter
    get :last_modified
    assert @response.headers['Last-Modified'] =~ /[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT/
  end

  def test_conditional_etag
    get :on_condition
    assert_response :ok

    @request.env['HTTP_IF_NONE_MATCH'] = 'magical'
    get :on_condition
    assert_response :not_modified

    @request.env['HTTP_IF_NONE_MATCH'] = 'foo'
    get :on_condition
    assert_response :ok

    @request.env['HTTP_IF_NONE_MATCH'] = '*'
    get :on_condition
    assert_response :not_modified

    @request.env['HTTP_IF_MATCH'] = '*'
    get :on_condition
    assert_response :not_modified
  end

  def test_conditional_last_modified
    get :on_condition
    assert_response :ok

    @request.env['HTTP_IF_UNMODIFIED_SINCE'] = Time.now - 10.minute
    get :on_condition
    assert_response :not_modified

    @request.env['HTTP_IF_UNMODIFIED_SINCE'] = Time.now 
    get :on_condition
    assert_response :ok
  end

end