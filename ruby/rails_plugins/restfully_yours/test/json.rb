require File.dirname(__FILE__) + '/../../../rails/actionpack/test/abstract_unit'
require File.dirname(__FILE__) + '/../../../rails/actionpack/test/active_record_unit'
$:.unshift File.expand_path('../../../rails/actionpack/lib/action_controller', File.dirname(__FILE__))
require 'integration'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


class JsonItemsController < ActionController::Base
  session :off

  def create
    render :json=>params[:json_item]
  end

  def upload
    render :json=>params[:json_items]
  end
end


class JsonRequestTest < Test::Unit::TestCase

  def setup
    @session = ActionController::Integration::Session.new
    routes = @routes = ActionController::Routing::RouteSet.new
    ActionController::Dispatcher.before_dispatch do
      ActionController::Routing.module_eval { remove_const :Routes }
      ActionController::Routing.module_eval { const_set :Routes, routes }
    end
  end

  def test_json_object
    @routes.draw { |map| map.resource 'json_items' }
    @session.post 'json_items', %{{ foo: 1, bar: "barred", baz: [2,3] }}, 'Content-Type'=>'application/json'
    assert_equal({ 'foo'=>1, 'bar'=>'barred', 'baz'=>[2,3] }, ActiveSupport::JSON.decode(@session.response.body))
  end

  def test_json_array
    @routes.draw { |map| map.resource 'json_items', :collection=>{ :upload=>:post } }
    @session.post 'json_items/upload', %{[ { foo: 1 }, { foo: 2 }]}, 'Content-Type'=>'application/json'
    assert_equal([{ 'foo'=>1 }, { 'foo'=>2 }], ActiveSupport::JSON.decode(@session.response.body))
  end

end
