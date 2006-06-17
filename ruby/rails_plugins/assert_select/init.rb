require "test/unit"
require File.join(File.dirname(__FILE__), "lib/assert_select")
Test::Unit::TestCase.send :include, Test::Unit::AssertSelect
