# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.


# A presenter is an object that renders another object, typically a model.  It handles presentation logic
# that you want to keep outside the model, and has access to the controller methods you can use to create
# URLs, format content and so forth.  Where helpers complement controllers, presenters complement models.
#
# For example:
#   class ItemPresenter < ActionController::Presenter
#     def to_xml()
#       to_hash.to_xml(:root=>"item")
#     end
#
#     def to_json()
#       to_hash.to_json
#     end
#
#     def to_hash()
#       { :url=>item_url(object), :name=>h(name), :sku=>sku }
#     end
#   end
#
# And from within the controller:
#   respond_to do |format|
#     format.html { render :action=>"item" }
#     format.xml  { render :xml=>presenting(@item).to_xml }
#     format.js   { render :json=>presenting(@item).to_json }
#   end
#
# Calling methods not defined in the presenter will pass the call to the model or controller.  You can
# also access the controller and object directly from the presenter.
#
# Presenters go in the app/presenters directory, so this example would reside in app/presenters/item_presenter.rb.
class Presenter # < Builder::BlankSlate

  module PresentingMethod

    # Returns a new presenter.  The presenter class is based on the object class, for example,
    # given the model Item and object item, <code>presenting(item)</code> will use the presenter
    # ItemPresenter.
    def presenting(*args)
      case args.first
      when Class
        name = args.shift.to_s
        object = args.shift
      when Symbol
        name = args.shift.to_s.capitalize
        object = args.shift
      when Array
        object = args.shift
        first = object.first
        name = first.class.name if object.all? { |e| e.is_a?(first.class) && Hash != first.class }
        raise ArgumentError, 'Call presenting with an array of objects of same type, or specify type as first argument' unless name
      else
        object = args.shift
        name = object.class.name
      end

      controller = self if ActionController::Base === self
      Class.const_get("#{name}Presenter").new(controller, object, :name=>name)
    rescue NameError
      raise "Cannot present object/array of type #{name}, no #{name}Presenter."
    end

  end

  self.extend PresentingMethod

  include ActionController::UrlWriter
  default_url_options[:host] = 'test.host' if RAILS_ENV == 'test'

  extend Forwardable

  # Returns the controller.  Useful for calling methods on the controller directly.
  attr_reader :controller

  # Returns the value.  Useful for calling methods on the value directly, or passing the value,
  # for example to url_for methods.
  attr_reader :value

  attr_reader :options

  # Creates a new presenter using the given controller and value.
  def initialize(controller, value, options = nil) #:nodoc:
    @controller, @value = controller, value
    @options = options || {}
  end 

  def name
    @options[:name]
  end

  # Renders the value depending on the request format.  Uses to_html, to_xml or to_json.
  # Passes options to tne controller render's method, e.g. :status or :layout.
  def render(render_options = {})
    format = controller.request.format
    output = { :text=>send("to_#{format.to_sym}"), :content_type=>format }
    controller.send :render, render_options.merge(output)
  end

  # Renders using partial template derived from the value's class name (e.g. _item.rhtml for Item).
  def to_html(options = {})
    if Array === @value
      controller.send(:render_to_string, :partial=>name.underscore, :collection=>@value, :locals=>{:options=>options})
    else
      controller.send(:render_to_string, :partial=>name.underscore, :object=>@value, :locals=>{:options=>options})
    end
  end

  # Converts to Hash (see #to_hash) and from there to XML using the value name as root element.
  # For example, for an ActiveRecord you could:
  #    render :json=>presenting(item).to_xml
  # It will use the root element "item" for the Item object.
  def to_xml(options = {})
    if Array === @value
      @value.map { |obj| to_hash(obj) }.to_xml(options.merge(:root=>name.pluralize.underscore))
    else
      to_hash(@value).to_xml(options.merge(:root=>name.underscore))
    end
  end

  # Converts to Hash (see #to_hash) and from there to JSON.  For example, for an ActiveRecord
  # you could:
  #    render :json=>presenting(item).to_json
  def to_json(options = {})
    if Array === @value
      @value.map { |obj| to_hash(obj) }.to_json(options)
    else
      to_hash(@value).to_json(options)
    end
  end

  def array?
    Array === @value
  end

protected

  # Shortcut for CGI::escapeHTML.
  def h(text)
    CGI::escapeHTML(text)
  end

  def url_for_with_controller(*args)
    if controller
      controller.url_for(*args)
    else
      url_for_without_controller(*args)
    end
  end
  alias_method_chain :url_for, :controller

  # Returns object as Hash.  Calls the attribute method on ActiveRecord objects, to_hash
  # on objects that respond to this method, or returns an empty hash.
  def to_hash(object)
    object.respond_to?(:attributes) ? object.attributes :
      object.respond_to?(:to_hash) ? object.to_hash : {}
  end

end


# That way we're able to use everything in app/presenters.
Dependencies.load_paths += %W( #{RAILS_ROOT}/app/presenters ) if defined?(RAILS_ROOT)
class ActionController::Base
protected
  include Presenter::PresentingMethod
end
