# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.

require File.dirname(__FILE__) + '/../../../rails/actionpack/test/abstract_unit'
require File.dirname(__FILE__) + '/../../../rails/actionpack/test/active_record_unit'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


class BeOkController < ActionController::Base
  def status()
    render :status=>params[:status].to_sym, :text=>params[:status]
  end
end


class BeOkTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = BeOkController.new
  end

  def test_ok
    get :status, :status=>:ok
    assert_response 200
    assert @response.ok?
  end

  def test_found
    get :status, :status=>:found
    assert_response 302
    assert @response.found?
  end

  def test_gone
    get :status, :status=>:gone
    assert_response 410
    assert @response.gone?
  end
end
