# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require "test/unit"
require File.join(File.dirname(__FILE__), "../lib", "scrapi")


class SelectorTest < Test::Unit::TestCase

    def setup
        Net::HTTP.reset_on_get
    end

    def teardown
        Net::HTTP.reset_on_get
    end

    def test_add_tests
    end

end
