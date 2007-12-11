require 'md5'

module ActionController #:nodoc:
  # Support for conditional GET (caching) and conditional PUT (conflict detection).
  #
  # Start by adding filters for your GET and PUT actions, for example:
  #   if_modified :@item, :only=>:show
  #   if_unmodified :@item, :only=>:update
  #
  # == Conditional GET
  module IfModified

    def self.included(mod)
      mod.extend ClassMethods
    end


    class Entity #:nodoc:
    
      class << self

        # Create new entity representation from request and arguments.
        def from(request, args)
          new(request, :last_modified=>last_modified_from(args), :etag=>etag_from(request, args))
        end

        # Calculates Last-Modified from arguments.  If all the arguments respond to updated_at, returns the
        # highest (most recent) time.  Otherwise, returns nil (unknown).
        def last_modified_from(args)
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
        # Returns the special value '' if all the ETags are nil -- used to detect no entity when performing
        # conditional PUT.
        def etag_from(request, args)
          return nil unless args.all? { |obj| obj.respond_to?(:etag) }
          tags = args.map(&:etag)
          return '' if tags.all?(&:nil?)
          tags.unshift request.format.to_s
          Digest::MD5.hexdigest(tags.join(';'))
        end

      end
      
      def initialize(request, args)
        @request = request
        @last_modified, @etag = args.values_at(:last_modified, :etag)
      end

      # Last-Modified Time.
      attr_reader :last_modified

      # ETag value.
      attr_reader :etag

      # Header value for ETag.
      def etag_header
        %{"#{@etag}"}
      end

      # Determines whether or not to perform a conditional request by comparing the
      # ETag and Last-Modified values (supplied as arguments) with the HTTP conditional
      # headers (supplied in the request).
      def conditional?
        return true unless last_modified || etag # Can't decide.
        unmodified_since = @request.headers['HTTP_IF_UNMODIFIED_SINCE'] &&
          Time.httpdate(@request.headers['HTTP_IF_UNMODIFIED_SINCE']) rescue nil
        return false if unmodified_since && (last_modified.nil? || last_modified > unmodified_since)
        match = @request.headers['HTTP_IF_MATCH'].to_s.split(/,/).map { |tag| tag.strip[/^("?)(.*)\1$/, 2] }.reject(&:blank?)
        return false unless match.blank? || (match.include?('*') && !etag.blank?) || match.include?(etag)
        modified_since = @request.headers['HTTP_IF_MODIFIED_SINCE'] &&
          Time.httpdate(@request.headers['HTTP_IF_MODIFIED_SINCE']) rescue nil
        return true if modified_since && last_modified && last_modified > modified_since
        none_match = @request.headers['HTTP_IF_NONE_MATCH'].to_s.split(/,/).map { |tag| tag.strip[/^("?)(.*)\1$/, 2] }.reject(&:blank?)
        return true unless etag.nil? || (none_match.include?('*') && !etag.blank?) || none_match.include?(etag)
        return none_match.blank? && !modified_since
      end

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
      entity = Entity.from(request, args)
      returning entity.conditional? do |perform|
        if perform
          yield
          etag! entity
        else
          response.headers['ETag'] ||= entity.etag_header
          head :not_modified
        end
      end
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
      returning Entity.from(request, args).conditional? do |perform|
        if perform
          yield
          etag! Entity.from(request, args)
        else
          head :precondition_failed
        end
      end
    end

  private

    def etag!(*args)
      if response.headers["Status"] =~ /^20[01]/
        entity = args.size == 1 && Entity === args.first ? args.first : Entity.from(request, args)
        response.headers['ETag'] ||= entity.etag_header if entity.etag
        response.headers['Last-Modified'] ||= entity.last_modified.httpdate if entity.last_modified
      end
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

    private

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

  end
end
