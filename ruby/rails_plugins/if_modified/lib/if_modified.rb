require 'md5'

module ActionController #:nodoc:
  module IfModified

    def self.included(mod)
      mod.extend ClassMethods
      mod.parent::AbstractRequest.send :include, RequestMethods
    end

    # Use this method to perform a conditional GET. 
    #
    # The method calculates the ETag and Last-Modified values from the arguments list and
    # compares them to the If-Modified-Since/If-None-Match headers sent by the client.
    #
    # If it determines the entity has changed, it yields to the block, and sets the
    # ETag and Last-Modified headers in the response.
    #
    # If it determines the entity has not changed, it sends back the 304 (Not Modified)
    # status code without yielding.
    #
    # For example:
    #   def show
    #     if_modified @item do
    #       render :action=>'show'
    #     end
    #   end
    def if_modified(*args)
      etag, last_modified = etag_from(args), last_modified_from(args)
      returning request.conditional?(:etag=>etag, :last_modified=>last_modified) do |perform|
        if perform
          yield
          response.headers['ETag'] ||= etag.blank? ? '' : %{"#{etag}"}
          response.headers['Last-Modified'] ||= last_modified.httpdate if last_modified
        else
          response.headers['ETag'] ||= etag.blank? ? '' : %{"#{etag}"}
          head :not_modified
        end
      end
      # TODO: Vary: Content-Type, JSON REQUEST
    end

    # Use this method to perform a conditional PUT. 
    #
    # The method calculates the ETag and Last-Modified values from the arguments list and
    # compares them to the If-Unmodified-Since/If-Match headers sent by the client.
    #
    # If it determines the entity has not changed, it yields to the block, and sets the
    # ETag and Last-Modified headers in the response.
    #
    # If it determines the entity has changed, it sends back the 412 (Precondition Failed)
    # status code without yielding.
    #
    # For example:
    #   def update
    #     if_unmodified @item do
    #       @item.update params[:item]
    #       render :action=>'show'
    #     end
    #   end
    def if_unmodified(*args)
      etag, last_modified = etag_from(args), last_modified_from(args)
      returning request.conditional?(:etag=>etag, :last_modified=>last_modified) do |perform|
        if perform
          yield
          etag, last_modified = etag_from(args), last_modified_from(args)
          response.headers['ETag'] ||= etag.blank? ? '' : %{"#{etag}"}
          response.headers['Last-Modified'] ||= last_modified.httpdate if last_modified
        else
          head :precondition_failed
        end
      end
    end

  protected

    # Calculates Last-Modified from arguments.  If all the arguments respond to updated_at, returns the
    # highest (most recent) time.  Otherwise, returns nil (unknown).
    def last_modified_from(*args)
      times = args.flatten.map { |obj| obj.updated_at if obj.respond_to?(:updated_at) }
      times.max unless times.any?(&:nil?)
    end

    # Calculates ETag from arguments.  If all the arguments respond to etag, calculates and returns an
    # ETag from that combination, otherwise returns nil (unknown).
    #
    # The resulting ETag is a hash calculated by combining all the returned etags and the request format.
    # Order of arguments is important and different orders result in different ETags (intentional).
    # The request format is use to calculate different ETags for different representations (e.g. HTML page
    # and AJAX request made to the same URL).
    #
    # Returns the special value '' if the arguments list is empty or all the etags are ''.
    def etag_from(*args)
      tags = args.flatten.map { |obj| obj.etag if obj.respond_to?(:etag) }
      return nil if tags.any?(&:nil?)
      return '' if tags.all?(&:empty?)
      tags.unshift request.format.to_s
      Digest::MD5.hexdigest(tags.join(';'))
    end


    module ClassMethods

      # Use this method to create an if-modified filter for conditional GET.
      #
      # The filter takes one entity, calculates the ETag and Last-Modified values and
      # compares those to the If-Modified-Since/If-None-Match headers sent by the client.
      #
      # If it determines the entity has changed, it performs the action and sets the
      # ETag/Last-Modified headers to the new values.
      #
      # If it determines the entity has not changed, it sends back the 304 (Not Modified)
      # status code without executing the action.
      #
      # The entity is extracted in one of three ways:
      # * By calling an instance method on the controller.
      # * From an instance variable of the controller.
      # * By calling a method or a proc.
      #
      # You can specify either one as the first argument to this method, or pass it in the
      # option :using.  The method also supports the filter :only and :except methods.
      #
      # For example:
      #   if_modified :item, :only=>:show
      def if_modified(*args)
        options = args.extract_options!
        extract = if_modified_extractor(options.delete(:using) || args.shift)

        around_filter options.slice(:only, :except) do |controller, action|
          controller.if_modified(extract[controller]) { action.call }
        end
      end

      # Use this method to create an if-unmodified filter for conditional PUT.
      #
      # The filter takes one entity, calculates the ETag and Last-Modified values and
      # compares those to the If-Unmodified-Since/If-Match headers sent by the client.
      #
      # If it determines the entity has not changed, it performs the action and sets the
      # ETag/Last-Modified headers to the new values.
      #
      # If it determines the entity has changed, it sends back the 412 (Precondition Failed)
      # status code.
      #
      # The entity is extracted in one of three ways:
      # * By calling an instance method on the controller.
      # * From an instance variable of the controller.
      # * By calling a method or a proc.
      #
      # You can specify either one as the first argument to this method, or pass it in the
      # option :using.  The method also supports the filter :only and :except methods.
      # Use this method to create an if-unmodified filter for conditional PUT.
      #
      # For example:
      #   if_unmodified :@item, :only=>:update
      def if_unmodified(*args)
        options = args.extract_options!
        extract = if_modified_extractor(options.delete(:using) || args.shift)

        around_filter options.slice(:only, :except) do |controller, action|
          controller.if_unmodified(extract[controller]) { action.call }
        end
      end

      def if_modified_extractor(extract) #:nodoc:
        case extract
        when Symbol, String
          if extract.to_s.starts_with?('@')
            lambda { |controller| controller.instance_variable_get(extract) }
          else
            lambda { |controller| controller.send(extract) }
          end
        when Proc, Method
          extract
        else raise ArgumentError, "Excepting first argument to be method or instance variable name, or :using option to be a block."
        end 
      end
      private :if_modified_extractor

    end

    module RequestMethods

      # Determines whether or not to perform a conditional request by comparing the
      # ETag and Last-Modified values (supplied as arguments) with the HTTP conditional
      # headers (supplied in the request).
      #
      # The :last_modified argument provides the last-modified time instance, if known.
      # The :etag argument provides the calculated etag, if known, using the empty string
      # to denote 'no entity'.
      def conditional?(options)
        last_modified, etag = options.values_at(:last_modified, :etag)
        return true unless last_modified || etag # Can't decide.
        unmodified_since = headers['HTTP_IF_UNMODIFIED_SINCE'] && Time.httpdate(headers['HTTP_IF_UNMODIFIED_SINCE']) rescue nil
        return false if unmodified_since && (last_modified.nil? || last_modified > unmodified_since)
        match = headers['HTTP_IF_MATCH'].to_s.split(/,/).map { |tag| tag.strip[/^("?)(.*)\1$/, 2] }.reject(&:blank?)
        return false unless match.blank? || (match.include?('*') && !etag.blank?) || match.include?(etag)
        modified_since = headers['HTTP_IF_MODIFIED_SINCE'] && Time.httpdate(headers['HTTP_IF_MODIFIED_SINCE']) rescue nil
        return true if modified_since && last_modified && last_modified > modified_since
        none_match = headers['HTTP_IF_NONE_MATCH'].to_s.split(/,/).map { |tag| tag.strip[/^("?)(.*)\1$/, 2] }.reject(&:blank?)
        return true unless etag.nil? || (none_match.include?('*') && !etag.blank?) || none_match.include?(etag)
        return none_match.blank? && !modified_since
      end

    end

  end
end
