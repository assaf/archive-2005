module ActionController
  class Base
    def see_other(location, formats = {})
      location = formats[request.format.to_sym] || location
      if location.is_a?(Hash)
        redirect_to location.merge(:status=>:see_other)
      else
        redirect_to location, :status=>:see_other
      end
    end
  end
end
