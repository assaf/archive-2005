module HTML
    unless const_defined? :Document
        require File.join(File.dirname(__FILE__), "html/document")
    end
end

module Scraper
    require File.join(File.dirname(__FILE__), "scraper/selector")
    require File.join(File.dirname(__FILE__), "scraper/reader")
    require File.join(File.dirname(__FILE__), "scraper/base")
end
