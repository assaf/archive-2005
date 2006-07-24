# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require "rubygems"
require "time"
require "test/unit"
require File.join(File.dirname(__FILE__), "mock_net_http")
require File.join(File.dirname(__FILE__), "../lib", "scrapi")


class ScraperTest < Test::Unit::TestCase

  def setup
    Net::HTTP.reset_on_get
  end

  def teardown
    Net::HTTP.reset_on_get
  end


  #
  # Tests selector methods.
  #

  def test_define_selectors
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test, "div"
    end
    assert_equal 3, scraper.test(scraper.document).size
    3.times do |i|
      assert_equal String(i + 1), scraper.test(scraper.document)[i].attributes["id"]
    end
  end


  def test_selector_blocks
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test, "div" do |elements|
        return elements[0..-2]
        elements[0..-2]
      end
    end
    assert_equal 2, scraper.test(scraper.document).size
  end


  def test_array_selectors
      html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
      scraper = new_scraper(html) do
        selector :test, "#?", "2"
      end
      assert_equal 1, scraper.test(scraper.document).size
      assert_equal "2", scraper.test(scraper.document)[0].attributes["id"]
  end


  def test_object_selectors
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test, HTML::Selector.new("div")
    end
    assert_equal 3, scraper.test(scraper.document).size
  end


  def test_selector_returns_array
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test0, "#4"
      selector :test1, "#1"
      selector :test3, "div"
    end
    assert_equal 0, scraper.test0(scraper.document).size # No elements (empty)
    assert_equal 1, scraper.test1(scraper.document).size # One element (array)
    assert_equal 3, scraper.test3(scraper.document).size # Array of elements
  end


  def test_select_in_document_order
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test, "#2,#1"
    end
    assert_equal 2, scraper.test(scraper.document).size
    assert_equal "1", scraper.test(scraper.document)[0].attributes["id"]
    assert_equal "2", scraper.test(scraper.document)[1].attributes["id"]
  end


  def test_selecting_first_element
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :test, "div"
    end
    assert_equal 3, scraper.test(scraper.document).size
    assert scraper.first_test(scraper.document)
    assert_equal "1", scraper.first_test(scraper.document).attributes["id"]

    scraper = new_scraper(html) do
      selector :test, "div" do |element|
        element[0].attributes["id"]
      end
    end
    assert scraper.first_test(scraper.document)
    assert_equal "1", scraper.first_test(scraper.document)
  end


  #
  # Tests process methods.
  #

  def test_processing_rule
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @count = (@count || 0) + 1
      end
      attr :count
    end
    scraper.scrape
    assert_equal 3, scraper.count
  end


  def test_processing_rule_with_array
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "#?", "1" do |element|
        @count = (@count || 0) + 1
      end
      attr :count
    end
    scraper.scrape
    assert_equal 1, scraper.count
  end


  def test_processing_rule_with_selector
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process HTML::Selector.new("div") do |element|
        @count = (@count || 0) + 1
      end
      attr :count
    end
    scraper.scrape
    assert_equal 3, scraper.count
  end


  def test_extracting_in_code
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @concat = (@concat || "") << element.attributes["id"]
      end
      attr :concat
    end
    scraper.scrape
    assert_equal "123", scraper.concat
  end


  def test_processing_in_document_order
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "#2,#1" do |element|
        @concat = (@concat || "") << element.attributes["id"]
      end
      attr :concat
    end
    scraper.scrape
    assert_equal "12", scraper.concat
  end


  def test_skip_if_extractor_returns_true
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "#1" do |element|
        @first = true
        false
      end
      process "#1" do |element|
        @second = true
      end
      attr :first
      attr :second
    end
    scraper.scrape
    assert_equal true, scraper.first
    assert_equal true, scraper.second
    scraper = new_scraper(html) do
      process "#1" do |element|
        @first = true
        true
      end
      process "#1" do |element|
        @second = true
      end
      attr :first
      attr :second
    end
    scraper.scrape
    assert_equal true, scraper.first
    assert_equal nil, scraper.second
  end


  def test_process_once_if_skipped
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "#1" do |element|
        @first = true
        skip element
        false
      end
      process "#1" do |element|
        @second = true
      end
      attr :first
      attr :second
    end
    scraper.scrape
    assert_equal true, scraper.first
    assert_equal nil, scraper.second
  end


  def test_skip_children
    html = %Q{<div><div id="1"></div><div id="2"></div><div id="3"></div></div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        if to_skip = id2(element)
          skip to_skip
        end
        false
      end
      selector :id2, "#2"
      attr :concat
    end
    scraper.scrape
    assert_equal "13", scraper.concat
  end


  def test_skip_descendants
    html = %Q{<div id="1"><div id="2"><div id="3"></div></div</div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        false
      end
      attr :concat
    end
    scraper.scrape
    # Root, child of root, grandchild of root.
    assert_equal "123", scraper.concat
    scraper = new_scraper(html) do
      process "div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        true
      end
      attr :concat
    end
    scraper.scrape
    # Stop at root.
    assert_equal "1", scraper.concat

    scraper = new_scraper(html) do
      process "div>div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        false
      end
      attr :concat
    end
    scraper.scrape
    # Child of root, and child of root's child
    assert_equal "23", scraper.concat
    scraper = new_scraper(html) do
      process "div>div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        true
      end
      attr :concat
    end
    scraper.scrape
    # Stop at child of root.
    assert_equal "2", scraper.concat

    scraper = new_scraper(html) do
      process "div div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        false
      end
      attr :concat
    end
    scraper.scrape
    # Child of root, the child of child of root.
    assert_equal "23", scraper.concat
    scraper = new_scraper(html) do
      process "div div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        true
      end
      attr :concat
    end
    scraper.scrape
    # Child of root.
    assert_equal "2", scraper.concat
  end


  def test_skip_from_extractor
    html = %Q{<div id="1">this</div>"}
    scraper = new_scraper(html) do
      process "#1", :this1=>:text
      process "#1", :this2=>:text
    end
    scraper.scrape
    assert_equal "this", scraper.this1
    assert_equal nil, scraper.this2

    scraper = new_scraper(html) do
      process "#1", :this1=>:text, :skip=>false
      process "#1", :this2=>:text
    end
    scraper.scrape
    #assert_equal "this", scraper.this1
    #assert_equal "this", scraper.this2

    scraper = new_scraper(html) do
      process "#1", :this1=>:text, :skip=>true do
        false
      end
      process "#1", :this2=>:text
    end
    scraper.scrape
    assert_equal "this", scraper.this1
    assert_equal nil, scraper.this2
  end


  def test_stop
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
        stop
      end
      attr :concat
    end
    scraper.scrape
    assert_equal "1", scraper.concat
  end


  def test_process_first
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process "div" do |element|
        @all = (@all || 0) + 1
        false
      end
      process_first "div" do |element|
        @first = (@first || 0) + 1
        false
      end
      attr :all
      attr :first
    end
    scraper.scrape
    assert_equal 3, scraper.all
    assert_equal 1, scraper.first
  end


  def test_accessors
    time = Time.new.rfc2822
    Net::HTTP.on_get do |address, path, headers|
      if path == "/redirect"
        response = Net::HTTPSuccess.new(Net::HTTP.version_1_2, 200, "OK")
        response["Last-Modified"] = time
        response["ETag"] = "etag"
        [response, %Q{
<html>
<head>
  <meta http-equiv="content-type" value="text/html; charset=other-encoding">
</head>
<body><div id="x"/></body>
</html>
        }]
      else
        response = Net::HTTPMovedPermanently.new(Net::HTTP.version_1_2, 300, "Moved")
        response["Location"] = "http://localhost/redirect"
        [response, ""]
      end
    end
    scraper = new_scraper(URI.parse("http://localhost/source"))
    scraper.scrape
    assert_equal "http://localhost/source", scraper.page_info.original_url.to_s
    assert_equal "http://localhost/redirect", scraper.page_info.url.to_s
    assert_equal time, scraper.page_info.last_modified
    assert_equal "etag", scraper.page_info.etag
    assert_equal "other-encoding", scraper.page_info.encoding
  end


  def test_scraping_end_to_end
    Net::HTTP.on_get do |address, path, headers|
      [Net::HTTPSuccess.new(Net::HTTP.version_1_2, 200, "OK"), %Q{
<html>
<body><div id="1"/><div id="2"/></body>
</html>
      }]
    end
    scraper = new_scraper(URI.parse("http://localhost/")) do
      process "div" do |element|
        @concat = (@concat || "") << (element.attributes["id"] || "")
      end
      attr :concat
    end
    scraper.scrape
    assert_equal "12", scraper.concat
  end


  #
  # Tests extractor methods.
  #

  def test_extractors
    html = %Q{<div id="1"></div>}
    scraper = new_scraper(html) do
      process "div", extractor(:div_id=>"@id")
      attr :div_id
    end
    scraper.scrape
    assert_equal "1", scraper.div_id
    scraper = new_scraper(html) do
      process "div", :div_id=>"@id"
      attr :div_id
    end
    scraper.scrape
    assert_equal "1", scraper.div_id
  end


  def test_text_and_element_extractors
    html = %Q{<div>some text</div>}
    # Extract the node itself.
    scraper = new_scraper(html) do
      process "div", extractor(:value=>:element)
      attr :value
    end
    scraper.scrape
    assert_equal "div", scraper.value.name
    # Extract the text value of the node.
    scraper = new_scraper(html) do
      process "div", extractor(:value=>:text)
      attr :value
    end
    scraper.scrape
    assert_equal "some text", scraper.value
  end


  def test_extractors_objects
    html = %Q{<h1 class="header"></h1><h2 class="header"></h2>}
    # Extract both elements based on class, return the second one.
    scraper = new_scraper(html) do
      process ".header", extractor(:header=>:element)
      attr :header
    end
    scraper.scrape
    assert_equal "h2", scraper.header.name
    # Extracting a specific element skips the second match.
    html = %Q{<h1 class="header"></h1><h2 class="header"></h2>}
    scraper = new_scraper(html) do
      process ".header", extractor(:header=>"h1")
      attr :header
    end
    scraper.scrape
    assert_equal "h1", scraper.header.name
  end


  def test_attribute_extractors
    # Extracting the attribute skips the second match.
    html = %Q{<abbr title="foo">bar</div><abbr>foo</abbr>}
    scraper = new_scraper(html) do
      process "abbr", extractor(:title=>"@title")
      attr :title
    end
    scraper.scrape
    assert_equal "foo", scraper.title
    # Extracting a specific element skips the second match.
    html = %Q{<h1 class="header" id="1"></h1><h2 class="header" id="2"></h2>}
    scraper = new_scraper(html) do
      process ".header", extractor(:header=>"h1@id")
      attr :header
    end
    scraper.scrape
    assert_equal "1", scraper.header
  end


  def test_class_extractors
    headers = Class.new(Scraper::Base)
    headers.instance_eval do
      root_element nil
      process "h1,h2", :h1=>"h1", :h2=>"h2"
      attr :h1
      attr :h2
    end
    html = %Q{<div><h1>first</h1><h2>second</h2></div>}
    scraper = new_scraper(html) do
      process "div", extractor(:headers=>headers)
      attr :headers
    end
    scraper.scrape
    assert scraper.headers
    assert_equal "h1", scraper.headers.h1.name
    assert_equal "h2", scraper.headers.h2.name
  end


  def test_array_extractors
    html = %Q{<div><h1>first</h1><h1>second</h1></div>}
    scraper = new_scraper(html) do
      process "h1", extractor("headers[]"=>:text)
      attr :headers
    end
    scraper.scrape
    assert scraper.headers.is_a?(Array)
    assert_equal 2, scraper.headers.size
    assert_equal "first", scraper.headers[0]
    assert_equal "second", scraper.headers[1]
  end


  def test_hash_extractors
    html = %Q{<div><h1 id="1" class="header">first</h1></div>}
    scraper = new_scraper(html) do
      process "h1", extractor("header"=>{:id=>"@id", :class=>"@class", :text=>:text})
      attr :header
    end
    scraper.scrape
    assert scraper.header.is_a?(Hash)
    assert_equal 3, scraper.header.size
    assert_equal "1", scraper.header[:id]
    assert_equal "header", scraper.header[:class]
    assert_equal "first", scraper.header[:text]
  end


  def test_multi_value_extractors
    html = %Q{<div><h1 id="1" class="header">first</h1></div>}
    scraper = new_scraper(html) do
      process "h1", [:text, :kls]=>Scraper.define {
        process "*", :text=>:text, :kls=>"@class"
      }
    end
    result = scraper.scrape
    assert "first", result.text
    assert "header", result.kls
  end


  def test_conditional_extractors
    # Look for id attribute (second header only),
    # if not found look for class attribute (first
    # two headers), otherwise just get text (third
    # header).
    html = %Q{<div><h1 class="foo">first</h1><h1 class="foo" id="bar">second</h1><h1>third</h1></div>}
    scraper = new_scraper(html) do
      process "h1", extractor("headers[]"=>["@id", "@class", :text])
      attr :headers
    end
    scraper.scrape
    assert scraper.headers.is_a?(Array)
    assert_equal 3, scraper.headers.size
    assert_equal "foo", scraper.headers[0]
    assert_equal "bar", scraper.headers[1]
    assert_equal "third", scraper.headers[2]
  end


  def test_accessors_from_extractor
    html = %Q{<div id="1">first</div><div id="2">second</div>}
    scraper = new_scraper(html) do
      process_first "div", :div_id=>"@id", :div_text=>:text
      result :div_id
    end
    value = scraper.scrape
    assert_equal "1", value

    scraper = new_scraper(html) do
      process_first "div", :div_id=>"@id", :div_text=>:text
      result :div_id, :div_text
    end
    value = scraper.scrape
    assert_equal "1", value.div_id
    assert_equal "first", value.div_text

    scraper = new_scraper(html) do
      process_first "div", :div_id=>"@id", :div_text=>:text
    end
    value = scraper.scrape
    assert_equal "1", value.div_id
    assert_equal "first", value.div_text

    scraper = new_scraper(html) do
      attr_accessor :div_class
      process_first "div", :div_id=>"@id", :div_text=>:text
      result :div_id, :div_class
    end
    value = scraper.scrape
    assert_equal "1", value.div_id
    assert_raise(NoMethodError) { value.div_text }

    scraper = new_scraper(html) do
      process "div", "div_ids[]"=>"@id"
      result :div_ids
    end
    value = scraper.scrape
    assert_equal "1", value[0]
    assert_equal "2", value[1]
  end


  def test_array_accessors
    html = %Q{<div id="1">first</div><div id="2">second</div>}
    scraper = new_scraper(html) do
      array :div_id, :div_text
      process "div", :div_id=>"@id", :div_text=>:text
      result :div_id, :div_text
    end
    value = scraper.scrape
    assert_equal 2, value.div_id.size
    assert_equal 2, value.div_text.size
    assert_equal "1", value.div_id[0]
    assert_equal "2", value.div_id[1]
    assert_equal "first", value.div_text[0]
    assert_equal "second", value.div_text[1]
  end


  #
  # Root element tests.
  #

  def test_scrape_body_by_default
    html = %Q{<html><head></head><body></body></html>}
    scraper = Class.new(Scraper::Base).new(html)
    scraper.class.instance_eval do
      process "head" do |element| @head = element end
      attr :head
      process "body" do |element| @body = element end
      attr :body
    end
    scraper.scrape
    assert scraper.head
    assert scraper.body
  end


  def test_changing_root_element
    html = %Q{<html><head></head><body></body></html>}
    only_header = new_scraper(html) do
      root_element "head"
      process "head" do |element| @head = element end
      attr :head
      process "body" do |element| @body = element end
      attr :body
    end
    only_body = Class.new(only_header.class).new(html)
    only_body.class.root_element "body"
    both_parts = Class.new(only_body.class).new(html)
    both_parts.class.root_element nil
    # We set this scraper to begin with the head element,
    # so we can see the head element, but not the body.
    only_header.scrape
    assert only_header.head
    assert only_header.body.nil?
    # Now switch to a scraper that processes the body element,
    # skipping the header.
    only_body.scrape
    assert only_body.head.nil?
    assert only_body.body
    # Now switch to a scraper that doesn't specify a root element,
    # and it will process both header and body.
    both_parts.scrape
    assert both_parts.head
    assert both_parts.body
  end


  # Test prepare/result.

  def test_prepare_and_result
    # Extracting the attribute skips the second match.
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      process("div") { |element| @count +=1 }
      define_method(:prepare) { @count = 1 }
      define_method(:result) { @count }
    end
    result = scraper.scrape
    assert_equal 4, result
  end


  def test_changing_document_from_prepare
    # Extracting the attribute skips the second match.
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = new_scraper(html) do
      selector :divs, "div"
      define_method :prepare do |document|
        @document = divs(document)[1]
      end
      array :ids
      process "div", :ids=>"@id"
      result :ids
    end
    result = scraper.scrape
    assert_equal 1, result.size
    assert_equal "2", result[0]
  end


  def test_anonymous_scrapers
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = Scraper.define do
      array :ids
      process "div", :ids=>"@id"
      result :ids
    end
    result = scraper.scrape(html)
    assert_equal "1", result[0]
    assert_equal "2", result[1]
    assert_equal "3", result[2]
  end


  def test_named_rules
    html = %Q{<div id="1"></div><div id="2"></div><div id="3"></div>}
    scraper = Scraper.define do
      array :ids1, :ids2
      process :main, "div", :ids1=>"@id"
      process :main, "div", :ids2=>"@id"
      result :ids1, :ids2
    end
    result = scraper.scrape(html)
    assert_equal nil, result.ids1
    assert_equal 3, result.ids2.size
    assert_equal "1", result.ids2[0]
    assert_equal "2", result.ids2[1]
    assert_equal "3", result.ids2[2]
  end


protected

  def new_scraper(what, &block)
    cls = Class.new(Scraper::Base)
    cls.root_element nil
    cls.parser :html_parser
    cls.instance_eval &block if block
    cls.new(what)
  end

end


# Repeats the same set of tests, but using Tidy instead of HTMLParser.
class ScraperUsingTidyTest < ScraperTest

protected

  def new_scraper(what, &block)
    cls = Class.new(Scraper::Base)
    cls.root_element nil
    cls.parser :tidy
    cls.instance_eval &block if block
    cls.new(what)
  end

end
