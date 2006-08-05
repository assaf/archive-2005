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
  # * +:name+         -- The human friendly name.
  # * +:description+  -- More expansive description.
  # * +:validate+     -- Optional block for validating inputs.
  Parameter = Struct.new(:name, :description, :validate)


  # Base class for holding meta-data about a blogging service.
  class Base

    class << self

      # Specifies the title for this service. The title should be a human
      # readable name, e.g. WordPress for the service :wordpress.
      def title(title)
        @title = title
      end


      # Declare a configuration parameter.
      #
      # A configuration parameter has a symbol by which it is known, a friendly name,
      # an optional description and an optional validation block.
      #
      # The validation block is called before setting a configuration parameter, and
      # can raise an ArgumentError if the value is invalid. Otherwise it may modify
      # but must return the desired parameter value.
      def parameter(symbol, title = nil, description = nil, &block)
        @params ||= {}
        title ||= symbol.to_s.titlelize
        @params[symbol] = Parameter.new(title, description, &block)
      end


      # Define what happens when rendering an RJS response to create a new post.
      #
      # The block is called with two arguments. The first argument is the +page+
      # object. The second argument are the inputs for the blog post (title,
      # content, etc).
      def render(&block)
        @render = block
      end

    end


    def initialize(params = nil)
      @params = {}
      if params
        params.delete :service
        params.each { |k,v| self[k] = v }
      end
    end


    # Returns the value of a service parameter.
    def [](symbol)
      @params[symbol]
    end


    # Sets the value of a service parameter. Raises ArgumentError if this service does
    # not support the parameter, or if the parameter value is invalid.
    def []=(symbol, value)
      if param = parameters[symbol]
        value = param.validate.call(value) if param.validate
        @params[symbol] = value
      else
        raise ArgumentError, "This blog service does not support the parameter #{name}"
      end
    end


    # Retuns a hash representing this service and its configuration.
    # You can store this and use it later on to recreate the service object.
    def to_hash()
      @params.merge({:service=>self.class.instance_variable_get(:@service)})
    end


    # Call this to render an RJS update that will create a new post on
    def render(page, inputs)
      self.class.instance_variable_get(:@render).call page, @params.merge(inputs)
    end


    # Returns the human readable title for this service.
    def title()
      self.class.instance_variable_get(:@title) || self.class.name
    end


    # Returns a description of each parameter supported by this service.
    # Returns a hash with the parameter key and Parameter object.
    def parameters()
      params = self.class.instance_variable_get(:@params)
      self.class.instance_variable_set(:@params, params = []) unless params
      params
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
  #       render do |page, inputs|
  #         . . .
  #       end
  #     end
  #   end
  module Services

    def self.service(name, &block)
      klass = Class.new(BlogThis::Base)
      klass.class_eval &block
      klass.instance_variable_set(:@service, name)
      const_set name.to_s.camelize, klass
    end

  end


  # Use this to render RJS code that will submit a new post.
  #
  # The first argument is the +page+ object. The second argument provides
  # the service configuration (see BlogThis::Base.to_hash) and the last
  # arguments are inputs to the post.
  def self.render(page, config, inputs)
    if klass = Services.const_get(config[:service].to_s.camelize)
      service = klass.new(config)
      service.render page, inputs
    else
      raise ArgumentError, "No such service #{inputs[:service]}"
    end
  end


protected

  def self.method_missing(symbol, *args)
    # The magic of creating a service by calling BlogThis.service.
    # For example, BlogThis.wordpress(:blog_url=>...). Service must
    # be defined first.
    if klass = Services.const_get(symbol.to_s.camelize)
      return klass.new(*args)
    else
      super
    end
  end

end


