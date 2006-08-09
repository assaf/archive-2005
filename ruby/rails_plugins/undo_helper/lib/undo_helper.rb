# Undo helper plugins for Rails
#
# Copyright (c) 2006 Assaf Arkin, under Creative Commons Attribution and/or MIT License
# Developed for http://co.mments.com
# Code and documention: http://labnotes.org


# Use the undo helper to maintain a list of undo actions and render
# a button to perform the last undo action.
#
# For example:
#   # Remove undo action from stack.
#   before_filter do |controller|
#     controller.undo.pop(controller.params) if controller.params[:undo]
#     true
#   end
#
#   def create()
#     # Do some action that can be undone.
#     record = Record.create(@params)
#     # Create a new undo action (if not itself an undo).
#     unless @params[:undo]
#       undo.push("Delete newly created record",
#         :action=>"delete", :id=>record.id)
#     end
#     # Using XHR unpdate the undo action on the page.
#     render :update do |page|
#       page["undo"].replace_html undo.render
#     end
#   end
module UndoHelper

  # Class representing the undo stack and operations that can be performed
  # on the stack (push, pop and render). Use UndoHelper.undo to create new
  # undo objects.
  class Undo


    # Default number of undo levels. Use #levels= to change the number
    # of undo levels.
    unless const_defined? :UNDO_LEVELS
      UNDO_LEVELS = 1
    end


    def initialize(view) #:nodoc:
      @view = view
      @session = view.session
    end


    # Set the number of undo levels.
    #
    # The default value is one, storing only the last undo action.
    #
    # For example, in <tt>environment.rb</tt>:
    #   UndoHelper::Undo.levels = 5
    def self.levels=(levels)
      @@levels = levels
    end


    # Returns the number of undo levels.
    def self.levels()
      @@levels || UNDO_LEVELS
    end


    # :call-seq:
    #   undo.push(title, url)
    #
    # Push a new undo action on the stack.
    #
    # The +title+ argument is used when rendering the undo button.
    # The +url+ argument is a hash used for the form action URL.
    # The parameter <tt>:undo=>true</tt> is automatically added.
    #
    # For example:
    #  undo.push("Delete newly created record",
    #    :controller=>"main", :action=>"delete", :id=>id)
    def push(title, url)
      if @session
        undos = @session[:undos] ||= []
        undos.shift while undos.size >= Undo.levels
        url = Hash[*url.collect{|k,v| [k.to_sym, v.to_s]}.flatten]
        url[:undo] = "true"
        undos << {:title=>title, :url=>url}
      end
      return
    end


    # :call-seq:
    #   undo.pop(params)
    #
    # Pop an undo entry from the stack. Call this when performing an undo
    # action to remove it from the stack, making the last undo action (or
    # no undo action) available.
    #
    # The request parameters are used to remove a specific undo action,
    # to deal with multiple pages at the same time.
    #
    # For example:
    #   undo.pop(@params) if @params[:undo]
    def pop(params = nil)
      if @session and undos = @session[:undos]
        undos.delete_if do |undo|
          undo[:url].all? { |k,v| params[k] == v }
        end
      end
      return
    end


    # :call-seq:
    #    undo.render(caption?, options?) => string
    #    undo.render(options?) { |undo, options| ... } => string
    #
    # Returns an undo form with a single button to invoke the last
    # undo action, or an empty string if there are no undo actions
    # and no disabled options specified.
    #
    # This method does not remove the undo action from the stack.
    #
    # When called without a block, returns a form for the last undo
    # action with a single button. Uses the specified caption and
    # formatting options. If missing, the default caption is "Undo".
    #
    # If there are no undo actions, returns an empty string. If there
    # are no undo actions but the <tt>:disabled</tt> option is specified,
    # returns a form with a button formatted using these options.
    #
    # The following options are supported:
    # * <tt>:form</tt> -- HTML options to format the +form+ tag.
    # * <tt>:button</tt> -- HTML options to format the +submit+ tag
    #   for an undo action.
    # * <tt>:disabled</tt> -- HTML options to format the +submit+ tag
    #   if there is no undo action.
    #
    # For example:
    #   undo.render "Undo", :form=>{:class=>"undo-form"},
    #      :button=>{:class=>"undo-button"}
    # 
    # When called with a block, yields the undo action and arguments to
    # block and returns the result. Yields a hash with the keys
    # <tt>:url</tt> and <tt>:title</tt> for the last undo action. Yields
    # +nil+ if there is no undo action on the stack.
    def render(*args)
      undos = @session[:undos]
      undo = undos.last if undos
      if block_given?
        return yield(undo, *args)
      end
      options = args[1] || {}
      form_html = options[:form] || {}
      form_html[:class] ||= "button"
      if undo
        button_html = options[:button] || {}
        button_html[:title] = undo[:title]
        return @view.form_remote_tag(:url=>undo[:url], :html=>form_html) +
               @view.submit_tag(args[0] || "Undo", button_html) +
               @view.end_form_tag
      elsif button_html = options[:disabled]
        button_html[:disabled] = true
        return @view.form_remote_tag(:html=>form_html) +
               @view.submit_tag(args[0] || "Undo", button_html) +
               @view.end_form_tag
      else
        return ""
      end
    end

  end


  # Returns an Undo object which you can use to push and pop undo actions.
  #
  # See Undo.push, Undo.pop and Undo.render.
  def undo
    Undo.new(self)
  end

end
