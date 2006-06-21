# ScrAPI toolkit for Ruby
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


require "uri"
require "net/http"
require "net/https"
require "tidy"


module Scraper

    module Reader

        class HTTPError < StandardError

            attr_reader :cause
    
            def initialize(cause = nil)
                @cause = cause
            end
        
        end

        class HTTPTimeoutError < HTTPError ; end
        class HTTPUnspecifiedError < HTTPError ; end
        class HTTPNotFoundError < HTTPError ; end
        class HTTPNoAccessError < HTTPError ; end
        class HTTPInvalidURLError < HTTPError ; end
        class HTTPRedirectLimitError < HTTPError ; end

        unless const_defined? :REDIRECT_LIMIT
            REDIRECT_LIMIT = 3
        end

        unless const_defined? :TIDY_OPTIONS
            TIDY_OPTIONS = {
                :output_xhtml=>true,
                :show_errors=>0,
                :show_warnings=>false,
                :wrap=>0,
                :wrap_sections=>false,
                :force_output=>true,
                :quiet=>true,
                :tidy_mark=>false
            }
        end


        # :call-seq:
        #   read_page(url, options?) => response
        #
        # Reads a Web page and return its URL, content and cache control headers.
        #
        # The request reads a Web page at the specified URL (must be a URI object).
        # It accepts the following options:
        # * :last_modified -- Last modified header (from a previous request).
        # * :etag -- ETag header (from a previous request).
        # * :redirect_limit -- Number of redirects allowed (default is 3).
        # * :user_agent -- The User-Agent header to send.
        #
        # It returns a hash with the following information:
        # * :url -- The URL of the requested page (may change by permanent redirect)
        # * :content -- The content of the response (may be nil if cached)
        # * :content_type -- The HTML page Content-Type header
        # * :last_modified -- Last modified cache control header (may be nil)
        # * :etag -- ETag cache control header (may be nil)
        # * :encoding -- Document encoding for the page
        # If the page has not been modified from the last request, the content is nil.
        #
        # Raises HTTPError if an error prevents it from reading the page.
        def self.read_page(url, options = nil)
            options ||= {}
            redirect_limit = options[:redirect_limit] || REDIRECT_LIMIT
            raise HTTPRedirectLimitError if redirect_limit == 0
            if url.is_a?(URI)
                uri = url
            else
                begin
                    uri = URI.parse(url)
                rescue Exception=>error
                    raise HTTPInvalidURLError.new(error)
                end
            end
            raise HTTPInvalidURLError unless uri.scheme =~ /^http(s?)$/
            begin
                http = Net::HTTP.new(uri.host, uri.port)
                http.use_ssl = (uri.scheme == "https")
                http.close_on_empty_response = true
                http.open_timeout = 30
                http.read_timeout = 30
                path = uri.path.dup # required so we don't modify path
                path << "?#{uri.query}" if uri.query
                # TODO: Specify which content types are accepted.
                # TODO: GZip support.
                headers = {}
                headers["User-Agent"] = options[:user_agent] if options[:user_agent]
                headers["Last-Modified"] = options[:last_modified] if options[:last_modified]
                headers["ETag"] = options[:etag] if options[:etag]
                response = http.request_get(path, headers)
                # TODO: Ignore content types that do not map to HTML.
            rescue TimeoutError=>error
                raise HTTPTimeoutError.new(error)
            rescue Exception=>error
                raise HTTPUnspecifiedError.new(error)
            end
            case response
            when Net::HTTPSuccess
                encoding = if content_type = response["Content-Type"]
                    if match = content_type.match(/charset=([^\s]+)/i)
                        match[1]
                    end
                end
                return {
                    :url=>(options[:source_url] || uri),
                    :content=>response.body,
                    :encoding=>encoding,
                    :last_modified=>response["Last-Modified"],
                    :etag=>response["ETag"]
                }
            when Net::HTTPNotModified
                return {
                    :url=>(options[:source_url] || uri),
                    :last_modified=>options[:last_modified],
                    :etag=>options[:etag]
                }
            when Net::HTTPMovedPermanently
                return read_page(response["location"], # New URL takes effect
                    :last_modified=>options[:last_modified],
                    :etag=>options[:etag],
                    :redirect_limit=>redirect_limit-1)
            when Net::HTTPRedirection
                return read_page(response["location"],
                    :last_modified=>options[:last_modified],
                    :etag=>options[:etag],
                    :redirect_limit=>redirect_limit-1,
                    :source_url=>(options[:source_url] || uri)) # Old URL still in effect
            when Net::HTTPNotFound
                raise HTTPNotFoundError
            when Net::HTTPUnauthorized, Net::HTTPForbidden
                raise HTTPNoAccessError
            when Net::HTTPRequestTimeOut
                raise HTTPTimeoutError
            else
                raise HTTPUnspecifiedError
            end
        end


        class HTMLParseError < StandardError

            attr_reader :cause

            def initialize(cause = nil)
                @cause = cause
            end

        end


        # :call-seq:
        #   parse_page(html, encoding?, tidy_options?) => html
        #
        # Parses an HTML page and returns the encoding and HTML element.
        # Raises HTMLParseError exceptions if it cannot parse the HTML.
        #
        # To use Tidy, pass a Hash with the required Tidy options.
        # If you don't have any specific options besides the default,
        # pass an empty Hash.
        def self.parse_page(content, encoding = nil, tidy_options = nil)
            begin
                # Get the document encoding from the meta header.
                if meta = content.match(/(<meta\s*([^>]*)http-equiv=['"]?content-type['"]?([^>]*))/i)
                    if meta = meta[0].match(/charset=([\w-]*)/i)
                        encoding = meta[1]
                    end
                end
                encoding ||= "utf8"
                # Parse HTML into HTML tree.
                if tidy_options
                    # Make sure the Tidy path is set and always apply the default
                    # options (these only control things like errors, output type).
                    find_tidy
                    tidy_options.update(TIDY_OPTIONS)
                    tidy_options[:input_encoding] = encoding.gsub("-", "").downcase
                    document = Tidy.open(tidy_options) do |tidy|
                        html = tidy.clean(content)
                        HTML::Document.new(html).find(:tag=>"html")
                    end
                else
                    document = HTML::HTMLParser.parse(content).root
                end
                return {:document=>document, :encoding=>encoding}
            rescue Exception=>error
                raise HTMLParseError.new(error)
            end
        end


protected

        def self.find_tidy()
            return if Tidy.path
            begin
                Tidy.path = File.join(File.dirname(__FILE__), "../tidy", "libtidy.so")
            rescue LoadError
                Tidy.path = File.join(File.dirname(__FILE__), "../tidy", "libtidy.dll")
            end
        end

    end

end
