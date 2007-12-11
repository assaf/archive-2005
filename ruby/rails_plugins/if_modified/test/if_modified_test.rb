require File.dirname(__FILE__) + '/../../../rails/actionpack/test/abstract_unit'
require File.dirname(__FILE__) + '/../../../rails/actionpack/test/active_record_unit'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


class IfModifiedController < ActionController::Base

  if_modified :instance, :only=>[:show] # Using instance method
  if_unmodified :@instance, :only=>[:update] # Using instance variable

  def show
    render :text=>'retrieved'
  end

  def update
    instance.etag = "modified-from-#{instance.etag}" unless instance.etag.empty?
    render :text=>'updated'
  end

protected

  attr_accessor :instance

end


class IfModifiedTest < Test::Unit::TestCase

  class Modified

    def initialize(updated_at = nil, etag = nil)
      @updated_at, @etag = updated_at, etag
    end

    attr_accessor :updated_at
    attr_accessor :etag

  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = IfModifiedController.new
    @time = Time.at(Time.now.to_i) # Discard usec
    @etag = MD5.hexdigest(__FILE__)
    @instance = Modified.new(@time, @etag)
    @controller.send :instance=, @instance
  end

  def etag_from(tag)
    Digest::MD5.hexdigest([@request.format, tag].join(';'))
  end


  # Test conditional? method.

  def test_conditional_with_no_headers
    # No conditions => true.
    assert @request.conditional?({})
    assert @request.conditional?(:last_modified=>@time)
    assert @request.conditional?(:etag=>@etag)
    assert @request.conditional?(:last_modified=>@time, :etag=>@etag)
  end

  def test_conditional_with_unmodified_since
    # Not modified since => true.
    @request.headers['HTTP_IF_UNMODIFIED_SINCE'] = @time.httpdate
    assert @request.conditional?(:last_modified=>@time)
    @request.headers['HTTP_IF_UNMODIFIED_SINCE'] = @time.httpdate
    assert @request.conditional?(:last_modified=>@time - 1.second)
    # Modified since => false
    @request.headers['HTTP_IF_UNMODIFIED_SINCE'] = @time.httpdate
    assert !@request.conditional?(:last_modified=>@time + 1.second)
  end

  def test_conditional_with_modified_since
    # Not modified since => false
    @request.headers['HTTP_IF_MODIFIED_SINCE'] = @time.httpdate
    assert !@request.conditional?(:last_modified=>@time)
    @request.headers['HTTP_IF_MODIFIED_SINCE'] = @time.httpdate
    assert !@request.conditional?(:last_modified=>@time - 1.second)
    # Modified since => true
    @request.headers['HTTP_IF_MODIFIED_SINCE'] = @time.httpdate
    assert @request.conditional?(:last_modified=>@time + 1.second)
  end
  
  def test_conditional_with_match
    # Same ETag => true
    @request.headers['HTTP_IF_MATCH'] = 'foo'
    assert @request.conditional?(:etag=>'foo')
    @request.headers['HTTP_IF_MATCH'] = '"bar", "foo"'
    assert @request.conditional?(:etag=>'foo')
    # Different ETag => false
    @request.headers['HTTP_IF_MATCH'] = 'bar'
    assert !@request.conditional?(:etag=>'foo')
  end

  def test_conditional_with_match_star
    # Can't decide => true
    @request.headers['HTTP_IF_MATCH'] = '*'
    assert @request.conditional?({})
    # Empty ETag => false
    assert !@request.conditional?(:etag=>'')
    # Any ETag => true
    assert @request.conditional?(:etag=>'foo')
    assert @request.conditional?(:etag=>'bar')
  end

  def test_conditional_with_none_match
    # Same ETag => false
    @request.headers['HTTP_IF_NONE_MATCH'] = 'foo'
    assert !@request.conditional?(:etag=>'foo')
    @request.headers['HTTP_IF_NONE_MATCH'] = '"bar", "foo"'
    assert !@request.conditional?(:etag=>'foo')
    # Different ETag => true
    @request.headers['HTTP_IF_NONE_MATCH'] = 'bar'
    assert @request.conditional?(:etag=>'foo')
  end

  def test_conditional_with_none_match_star
    # Can't decide => true
    @request.headers['HTTP_IF_NONE_MATCH'] = '*'
    assert @request.conditional?({})
    # Empty ETag => true
    assert @request.conditional?(:etag=>'')
    # Any ETag => false
    assert !@request.conditional?(:etag=>'foo')
    assert !@request.conditional?(:etag=>'bar')
  end

  def test_conditional_modified
    @request.headers['HTTP_IF_MODIFIED_SINCE'] = @time.httpdate
    @request.headers['HTTP_IF_NONE_MATCH'] = '"foo"'
    # Same entity, unmodified => false
    assert !@request.conditional?(:last_modified=>@time, :etag=>'foo')
    # Same entity, modified since => true
    assert @request.conditional?(:last_modified=>@time + 1.second, :etag=>'foo')
    # Different entity, unmodified => true
    assert @request.conditional?(:last_modified=>@time, :etag=>'bar')
    # Either one.
    assert @request.conditional?(:last_modified=>@time + 1.second, :etag=>'bar')
  end

  def test_conditional_unmodified
    @request.headers['HTTP_IF_UNMODIFIED_SINCE'] = @time.httpdate
    @request.headers['HTTP_IF_MATCH'] = '"foo"'
    # Same entity, unmodified => true
    assert @request.conditional?(:last_modified=>@time, :etag=>'foo')
    # Same entity, modified since => false
    assert !@request.conditional?(:last_modified=>@time + 1.second, :etag=>'foo')
    # Different entity, unmodified => true
    assert !@request.conditional?(:last_modified=>@time, :etag=>'bar')
    # Either one.
    assert !@request.conditional?(:last_modified=>@time + 1.second, :etag=>'bar')
  end

  def test_conditional_with_no_values
    @request.headers['HTTP_IF_MODIFIED_SINCE'] = @time.httpdate
    @request.headers['HTTP_IF_NONE_MATCH'] = '"foo"'
    assert @request.conditional?({})
    @request.headers.clear
    @request.headers['HTTP_IF_UNMODIFIED_SINCE'] = @time.httpdate
    @request.headers['HTTP_IF_MATCH'] = '"foo"'
    assert @request.conditional?({})
  end


  # GET

  def test_get_no_headers
    get :show
    assert_response :ok
  end

  def test_get_etag_match
    @request.headers['HTTP_IF_NONE_MATCH'] = %{"#{etag_from @etag}"}
    get :show
    assert_response :not_modified
  end

  def test_get_etag_match_from_array
    @request.headers['HTTP_IF_NONE_MATCH'] = %{"foo", "#{etag_from @etag}", "bar"}
    get :show
    assert_response :not_modified
  end

  def test_get_etag_no_match
    @request.headers['HTTP_IF_NONE_MATCH'] = '"foo"'
    get :show
    assert_response :ok
  end

  def test_get_etag_match_nothing
    @request.headers['HTTP_IF_NONE_MATCH'] = '"*"'
    get :show
    assert_response :not_modified
  end

  def test_get_etag_match_anything
    @request.headers['HTTP_IF_MATCH'] = '"*"'
    get :show
    assert_response :ok
  end

  def test_get_etag_match_against_empty
    @instance.etag = ''
    @request.headers['HTTP_IF_MATCH'] = '"*"'
    get :show
    assert_response :not_modified
  end

  def test_get_body_and_headers
    get :show
    assert_match etag_from(@etag), @response.headers['ETag']
    assert_equal @time.httpdate, @response.headers['Last-Modified']
    assert_equal 'retrieved', @response.body
  end

  def test_not_modified_body_and_headers
    @request.headers['HTTP_IF_NONE_MATCH'] = %{"#{etag_from @etag}"}
    get :show
    assert_match etag_from(@etag), @response.headers['ETag']
    assert_nil @response.headers['Last-Modified']
    assert @response.body.blank?
  end

  def test_get_etag_for_empty
    @instance.etag = ''
    get :show
    assert_equal '', @response.headers['ETag']
  end


  # PUT

  def test_put_no_headers
    put :update
    assert_response :ok
  end

  def test_put_etag_match
    @request.headers['HTTP_IF_MATCH'] = %{"#{etag_from @etag}"}
    put :update
    assert_response :ok
  end

  def test_put_etag_match_from_array
    @request.headers['HTTP_IF_MATCH'] = %{"foo", "#{etag_from @etag}", "bar"}
    put :update
    assert_response :ok
  end

  def test_put_etag_no_match
    @request.headers['HTTP_IF_MATCH'] = '"foo"'
    put :update
    assert_response :precondition_failed
  end

  def test_put_etag_match_anything
    @request.headers['HTTP_IF_MATCH'] = '"*"'
    put :update
    assert_response :ok
  end

  def test_put_etag_match_against_empty
    @instance.etag = ''
    @request.headers['HTTP_IF_MATCH'] = '"foo"'
    put :update
    assert_response :precondition_failed
  end

  def test_put_etag_match_empty
    @instance.etag = ''
    @request.headers['HTTP_IF_NONE_MATCH'] = '"*"'
    put :update
    assert_response :ok
  end

  def test_put_body_and_headers
    put :update
    assert_match etag_from(@instance.etag), @response.headers['ETag']
    assert_equal @time.httpdate, @response.headers['Last-Modified']
    assert_equal 'updated', @response.body
  end

  def test_precondition_failed_body_and_headers
    @request.headers['HTTP_IF_MATCH'] = '"foo"'
    put :update
    assert_nil @response.headers['ETag']
    assert_nil @response.headers['Last-Modified']
    assert @response.body.blank?
  end

  def test_put_etag_for_empty
    @instance.etag = ''
    put :update
    assert_equal '', @response.headers['ETag']
  end


  # Test ETag/Last-Modified calculation.

  def test_last_modified_from_empty
    assert_equal nil, @controller.send(:last_modified_from, nil)
    assert_equal nil, @controller.send(:last_modified_from, [])
    assert_equal nil, @controller.send(:last_modified_from, [nil])
  end

  def test_last_modified_from_regular_objects
    assert_equal nil, @controller.send(:last_modified_from, Object.new)
    assert_equal nil, @controller.send(:last_modified_from, [Object.new])
    assert_equal nil, @controller.send(:last_modified_from, [Object.new, Object.new])
  end

  def test_last_modified_from_objects_with_updated_at
    assert_equal nil, @controller.send(:last_modified_from, Modified.new)
    assert_equal @time, @controller.send(:last_modified_from, Modified.new(@time))
    assert_equal @time, @controller.send(:last_modified_from, Modified.new(@time - 1.minute), Modified.new(@time))
  end

  def test_etag_from_empty
    assert_equal nil, @controller.send(:etag_from, nil)
    assert_equal '', @controller.send(:etag_from, [])
    assert_equal nil, @controller.send(:etag_from, [nil])
  end

  def test_etag_from_regular_objects
    assert_equal nil, @controller.send(:etag_from, Object.new)
    assert_equal nil, @controller.send(:etag_from, [Object.new])
    assert_equal nil, @controller.send(:etag_from, [Object.new, Object.new])
  end

  def test_etag_from_objects_with_etag
    get :show # sets up request for controller
    assert_equal nil, @controller.send(:etag_from, Modified.new)
    assert_equal etag_from(@etag), @controller.send(:etag_from, Modified.new(nil, @etag))
    assert_equal '', @controller.send(:etag_from, Modified.new(nil, ''))
  end

  def test_etag_from_equivalence
    get :show # sets up request for controller
    foo, bar = Modified.new(nil, 'foo'), Modified.new(nil, 'bar')
    assert_equal @controller.send(:etag_from, foo), @controller.send(:etag_from, Modified.new(nil, 'foo'))
    assert_equal @controller.send(:etag_from, bar), @controller.send(:etag_from, Modified.new(nil, 'bar'))
    assert_not_equal @controller.send(:etag_from, foo), @controller.send(:etag_from, bar)
  end

  def test_etag_from_for_array
    get :show # sets up request for controller
    foo, bar = Modified.new(nil, 'foo'), Modified.new(nil, 'bar')
    assert_equal @controller.send(:etag_from, foo, bar), @controller.send(:etag_from, foo, bar)
    assert_not_equal @controller.send(:etag_from, foo, bar), @controller.send(:etag_from, bar, foo)
  end
  
end
