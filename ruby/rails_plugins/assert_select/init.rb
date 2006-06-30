require File.join(File.dirname(__FILE__), "lib", "assert_select")
Test::Unit::Assertions.send :include, Test::Unit::AssertSelect
