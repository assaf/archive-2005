$:.unshift File.expand_path('../../../rails', File.dirname(__FILE__))
require 'actionpack/test/abstract_unit'
require 'actionpack/test/active_record_unit'
$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require File.dirname(__FILE__) + '/../init'


ActiveRecord::Base.connection.execute <<-SQL
CREATE TABLE 'with_versions' (
'id' INTEGER NOT NULL PRIMARY KEY,
'tps_report_number' INTEGER DEFAULT NULL,
'version' INTEGER NOT NULL DEFAULT 0
);
SQL

class IfModifiedETagTest < Test::Unit::TestCase

  class Topic < ActiveRecord::Base
  end

  class Topic2 < Topic
    attr_protected :subtitle
  end

  class WithVersion < ActiveRecord::Base
    set_locking_column 'version'
  end

  def setup
    @etag = MD5.hexdigest(__FILE__)
  end

  def test_new_record
    assert_nil Topic.new.etag
  end

  def test_saved_record
    assert_not_nil Topic.create.etag
  end

  def test_record_identity  
    one, two = Topic.create, Topic.create
    assert_equal one.etag, one.etag
    assert_equal two.etag, two.etag
    assert_not_equal one.etag, two.etag
  end

  def test_equality_across_loading
    topic = Topic.create
    first, second = Topic.find(topic.id), Topic.find(topic.id)
    assert !first.equal?(second)
    assert_equal topic.etag, first.etag
    assert_equal first.etag, second.etag
  end

  def test_attribute_change
    topic = Topic.create
    before_change = topic.etag
    topic.title = 'Something else'
    assert_not_equal before_change, topic.etag
  end

  def test_protected_attribute_change
    topic = Topic2.create
    before_change = topic.etag
    topic.subtitle = 'Something else'
    assert_not_equal before_change, topic.etag
  end

  def test_class_difference
    topic2 = Topic2.create.reload
    topic = Topic.find(topic2.id)
    assert topic.attributes == topic2.attributes
    assert_not_equal topic.etag, topic2.etag 
  end

  def test_version_based
    version1 = WithVersion.create
    version2 = WithVersion.find(version1.id)
    assert_equal version1.etag, version2.etag
    version2.save
    assert_not_equal version1.etag, version2.etag
  end

  def teardown
    Topic.delete_all
  end

end
