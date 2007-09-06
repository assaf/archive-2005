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

  module PresentingMethods

  protected

    # Returns a new presenter.  The presenter class is based on the object class, for example,
    # given the model Item and object item, <code>presenting(item)</code> will use the presenter
    # ItemPresenter.
    def presenting(object)
      Class.const_get("#{object.class.name}Presenter").new(self, object)
    rescue NameError
      raise "Cannot present object of type #{object.class.name}, no #{object.class.name}Presenter."
    end

  end

  include ActionController::UrlWriter
  extend Forwardable

  # Returns the controller.  Useful for calling methods on the controller directly.
  attr_reader :controller

  # Returns the object.  Useful for calling methods on the object directly, or passing the object,
  # for example to url_for methods.
  attr_reader :object

  # Creates a new presenter using the given controller and object.
  def initialize(controller, object) #:nodoc:
    @controller, @object = controller, object
  end 

  # Renders the object depending on the request format.  Uses to_html, to_xml or to_json.
  # Passes options to tne controller render's method, e.g. :status or :layout.
  def render(options = {})
    controller.respond_to do |format|
      format.html { controller.send :render, options.merge(:text=>to_html) }
      format.xml  { controller.send :render, options.merge(:xml=>to_xml) }
      format.js   { controller.send :render, options.merge(:text=>to_json) }
    end
  end

  # Renders using partial template derived from the object's class name (e.g. _item.rhtml for Item).
  def to_html()
    controller.send(:render_to_string, :partial=>object.class.name.underscore, :object=>object)
  end

  # Converts to Hash (see #to_hash) and from there to XML using the object name as root element.
  # For example, for an ActiveRecord you could:
  #    render :json=>presenting(item).to_xml
  # It will use the root element "item" for the Item object.
  def to_xml()
    to_hash.to_xml(:root=>object.name.dasherize)
  end

  # Converts to Hash (see #to_hash) and from there to JSON.  For example, for an ActiveRecord
  # you could:
  #    render :json=>presenting(item).to_json
  def to_json()
    to_hash.to_json
  end

  def respond_to?(sym) #:nodoc:
    super || object.respond_to?(sym)
  end

protected

  # Shortcut for CGI::escapeHTML.
  def h(text)
    CGI::escapeHTML(text)
  end

  def url_for(*args)
    controller.url_for(*args)
  end

  # Returns object as Hash.  Calls the attribute method on ActiveRecord objects, to_hash
  # on objects that respond to this method, or returns an empty hash.
  def to_hash()
    object.respond_to?(:attributes) ? object.attributes :
      object.respond_to?(:to_hash) ? object.to_hash : {}
  end

private

  def method_missing(sym, *args, &block)
    object.send(sym, *args, &block)
  end

end
