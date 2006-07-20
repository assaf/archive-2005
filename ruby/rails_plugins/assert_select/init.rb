require File.join(File.dirname(__FILE__), "lib", "assert_select")
require File.join(File.dirname(__FILE__), "lib", "html_selector")
Test::Unit::Assertions.send :include, Test::Unit::AssertSelect
