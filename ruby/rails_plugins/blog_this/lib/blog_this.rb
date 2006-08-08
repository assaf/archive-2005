# blog_this plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


# == Define a blogging service
#
# To define a blogging service, use the BlogThis::Services module and the method
# BlogThis::Services#service. For example:
#   module BlogThis::Services
#     service :blogger do
#       title "Blogger"
#       render do |page, inputs|
#         . . .
#       end
#     end
#   end
#
# == Configure to a blog
#
# Once you defined a blogging service, you'll want to create objects and configure
# them with parameters, for example, the blog URL or identifier.
#   wordpress = BlogThis.wordpress :blog_url=>"http://blog.labnotes.org"
# or:
#   wordpress = BlogThis.wordpress
#   wordpress.blog_url = "http://blog.labnotes.org"
#
# You will then want to store these configurations, so get the configuration as
# a hash:
#   yaml = YAML::dump(wordpress.to_hash)
#
# == Render a new post
#
# Get the blog configuration and re-create the object:
#   wordpress = BlogThis.wordpress(YAML::load(yaml))
# Render from within your controller:
#   render :update do |page|
#     wordpress.render page, :title=>"Blogging about..."
#   end
# Or:
#   config = YAML::load(yaml)
#   render :update do |page|
#     BlogThis.render page, config, :title=>"Blogging about..."
#   end
#
# == Configuration and inputs
#
# Which configuration you use depends on the blog service. It may require a blog
# URL, blog ID, etc. Some services expect the user to login and select their blog.
#
# Which inputs you use also depends on the blog service, but for maximum effect,
# use the same set of inputs. The services included here use these inputs:
# * +:title:    -- The post title (entity encoded)
# * +:content:  -- The post content (HTML encoded)
# * +:url:      -- A link URL.
module BlogThis


  # A configuration parameter. Has the following attributes:
  # * +:label+    -- Human readable name.
  # * +:validate+ -- Optional proc for validating inputs.
  Parameter = Struct.new(:label, :validate)


  # Base class for holding a blog service configuration.
  class Base

    class << self

      # Specifies the label for this service. The label should be human
      # readable, e.g. "WordPress" for the service :wordpress.
      def label(label = nil)
        @label = label if label
        @label || self.class.name
      end


      # A description that is rendered when the user selects the service,
      # and can guide the user in configuring the service.
      def description(desc)
        @description = desc
      end


      # Defines a configuration parameter.
      #
      # A configuration parameter has a symbol for accessing and storing its value,
      # and a human readable label (e.g. :blog_url and "Blog URL").
      #
      # In addition it has an optional validation proc. This proc is called with an
      # input value and may return the same or different input value, or raise an
      # ArgumentError if the input value is invalid.
      def parameter(symbol, label = nil, &block)
        @params ||= {}
        label ||= symbol.to_s.titlelize
        @params[symbol] = Parameter.new(label, block)
      end


      # Creates inputs for making an HTTP request to blog the specified content.
      #
      # This block is called with these three inputs:
      # * +:title+   -- The post title.
      # * +:content+ -- The post content.
      # * +:url+     -- The URL associated with the post
      #
      # Returns a hash with the following values:
      # * +:url+      -- URL to blog service to create a new post.
      # * +:title+    -- Title for popup window.
      # * +:options+  -- Other options for use with popup window.
      def request(&block)
        @request = block
      end

    end


    def initialize(params = nil)
      @params = {}
      if params
        params.delete :service
        params.each { |k,v| self[k] = v }
      end
    end


    # Returns the value of a service configuration parameter.
    def [](name)
      @params[name]
    end


    # Sets the value of a service configuration parameter. Raises ArgumentError if
    # this service does not support the parameter, or if the parameter value is invalid.
    def []=(name, value)
      params = self.class.instance_variable_get(:@params)
      if params and param = params[name]
        if param.validate
          value = param.validate.call(value) rescue value
        end
        #value = param.validate.call(value) if param.validate
        @params[name] = value
      else
        raise ArgumentError, "This blog service does not support the parameter #{name}"
      end
    end


    def validate()
      if params = self.class.instance_variable_get(:@params)
        params.each do |name, param|
          @params[name] = param.validate.call(@params[name]) if param.validate
        end
      end
    end


    # Returns a hash of this service configuration. You can use this hash to
    # recreate the service configuration with BlogThis#recreate.
    def to_hash()
      @params.merge({:service=>self.class.instance_variable_get(:@service)})
    end


    # Call this to create inputs for an HTTP request that will blog the specified
    # content.
    #
    # Call this method with:
    # * +title+   -- The post title.
    # * +content+ -- The post content.
    # * +url+     -- The URL associated with the post
    #
    # Returns a hash with the following values:
    # * +:url+      -- URL to blog service to create a new post.
    # * +:title+    -- Title for popup window.
    # * +:options+  -- Other options for use with popup window.
    def request(title, content, url)
      self.class.instance_variable_get(:@request).call title, content, url
    end


    # Returns the human readable label for this service.
    def label()
      self.class.label
    end


    # A description that is rendered when the user selects the service,
    # and can guide the user in configuring the service.
    def description()
      self.class.instance_variable_get(:@description)
    end


    # Returns a description of each parameter supported by this service.
    # Returns a hash with the parameter key and its label.
    def parameters()
      if params = self.class.instance_variable_get(:@params)
        Hash[*params.map{ |k,v| [k,v.label] }.flatten]
      else
        {}
      end
    end


    # Return this service name (note: not #label).
    def name()
      self.class.instance_variable_get(:@service)
    end


protected

    def method_missing(symbol, *args)
      if symbol.to_s[-1] == ?=
        @params[symbol.to_s[0...-1].to_sym] = args[0]
      else
        @params[symbol]
      end
    end

  end


  # To define new blogging services, use this module and the #service method.
  # For example:
  #   module BlogThis::Services
  #     service :blogger do
  #       title "Blogger"
  #       request do |title, content, url|
  #         . . .
  #       end
  #     end
  #   end
  module Services

    @@services = {}


    def self.service(name, &block)
      name = name.to_sym
      klass = Class.new(BlogThis::Base)
      klass.class_eval &block
      klass.instance_variable_set(:@service, name)
      const_set name.to_s.camelize, klass
      @@services[name] = klass
    end


    # Returns a hash of all services, using the service ID as the key,
    # and the service label as the value.
    def self.list()
      Hash[*@@services.map { |k, v| [k, v.label] }.flatten]
    end

  end


  # Recreate a service from its configuration. See BlogThis::Base.to_hash.
  # Returns nil if the service could not be found, or the configuration is
  # invalid.
  def self.recreate(config)
    return nil unless name = config[:service]
    return nil unless klass = Services.const_get(name.to_s.camelize) rescue nil
    return klass.new(config) rescue nil
  end


  # Returns a new unconfigured service based on the service identifier.
  def self.service(name)
    if klass = Services.const_get(name.to_s.camelize) rescue nil
      return klass.new
    end
  end


protected

  def self.method_missing(symbol, *args)
    # The magic of creating a service by calling BlogThis.service.
    # For example, BlogThis.wordpress(:blog_url=>...). Service must
    # be defined first.
    if klass = Services.const_get(symbol.to_s.camelize) rescue nil
      return klass.new(*args)
    else
      super
    end
  end

end


