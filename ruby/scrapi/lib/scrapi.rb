module HTML #:nodoc:
    # Conditional loads, since we may have these libraries elsewhere,
    # e.g. when using Rails with assert_select plugin.
    require File.join(File.dirname(__FILE__), "html/document") unless
        const_defined? :Document
    require File.join(File.dirname(__FILE__), "html/selector") unless
        const_defined? :Selector
    require File.join(File.dirname(__FILE__), "html/htmlparser") unless
        const_defined? :HTMLParser
end


module Scraper #:nodoc:
    require File.join(File.dirname(__FILE__), "scraper/reader")
    require File.join(File.dirname(__FILE__), "scraper/base")
end
