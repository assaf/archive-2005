module ActionController
  # Handles JSON requests.
  #
  # When receiving a request with a JSON object/array, parses the request into a hash/array.
  # Since the request is unnamed, figures the parameter name based on the controller name.
  # For example, for the controller ItemsController, maps a JSON object as Hash into the
  # parameter :item, and JSON array into the parameter :items.  If you need to pick a different
  # parameter name, override #unwrapped_parameter_name.
  module JsonRequest
    def self.included(mod)
      super
      mod.param_parsers[Mime::JSON] = lambda { |body| { :_unwrapped => ActiveSupport::JSON.decode(body) }.with_indifferent_access }
      mod.alias_method_chain :assign_names, :unwrapped_parameter
    end

    def assign_names_with_unwrapped_parameter
      assign_names_without_unwrapped_parameter
      if data = params.delete('_unwrapped')
        name = unwrapped_parameter_name(data.is_a?(Array))
        params.update(name=>data)
      end
    end
    private :assign_names_with_unwrapped_parameter

    # Picks a name for the unwrapped parameter.  The default implementation uses the controller name
    # when +plural+ is true, and controller name made singular otherwise.
    def unwrapped_parameter_name(plural)
      plural ? controller_name : controller_name.singularize
    end
    protected :unwrapped_parameter_name
  end
end 

ActionController::Base.send :include, ActionController::JsonRequest
