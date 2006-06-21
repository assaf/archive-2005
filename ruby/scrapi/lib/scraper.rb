module HTML
    unless const_defined? :Document
        require File.join(File.dirname(__FILE__), "html/document")
    end
    unless const_defined? :Selector
        require File.join(File.dirname(__FILE__), "html/selector")
    end
end

module Scraper #:nodoc:
    require File.join(File.dirname(__FILE__), "scraper/reader")
    require File.join(File.dirname(__FILE__), "scraper/base")
end
