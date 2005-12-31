require 'net/http'
require 'uri'
require 'json'
require 'pp'

=begin

    # Call this method if the response message is JSON. It will return a Ruby
    # object from the JSON message. Use a pattern if the response includes
    # a JavaScript callback.
    #
    # For example, if the response is a JSON string:
    #   method :search do
    #     response_as_json
    #   end
    #
    # If the response is a JavaScript callback:
    #   method :search do
    #     response_as_json /$callback\((.*)\)^/
    #   end
    # This will strip the JSON object from the JavaScript call to the function
    # callback().
    #
    # The block can be used to further process the JSON object, e.g. to identify
    # an error response and raise an exception. For example:
    #
    #  response_as_json do |obj|
    #    if obj.error
    #       raise ServiceException, obj.error.string
    #    end
    #  end
    #
    # :call-seq:
    #   response_as_json(pattern?)
    #
    def response_as_json(pattern = nil, &block)
        to_object do |response|
            json = pattern ? response.body.match(pattern)[0] : response.body
            obj = JSON::load(json)
            block.call(obj) if block
            obj
        end
    end

    # Call this method is the response message is XML. It will return an REXML
    # document created from parsing the response mesage.
    #
    # The block can be used to further process the XML, e.g. to identify
    # an error response and raise an exception. For example:
    #
    #  response_as_rexml do |doc|
    #    if doc.root.name == 'error'
    #       raise ServiceException, doc.get_elements('error/message')[0]
    #    end
    #  end
    #
    def response_as_rexml
        to_object do |response|
            REXML::load(response.body)
        end
    end


    def to_object(response = nil, &block)
        if &block
            # Define how to return object from response.
            @to_object = block
        elsif response
            # TODO: delegate to parent?
            @to_object ? @to_object.call(response) :
                (@parent ? @parent.to_object(response) : response.body)
        else
            raise ArgumentError, "Call to_object with a block that will extract an object from the response"
        end
    end
=end


class WebCall

    attr_reader :url, :request_bindings, :stages, :params

    def initialize(value)
        case value
        when URI
            @url = value
            @params = {}
        when String
            @url = URI.parse(value)
            @params = {}
        when WebCall
            @url = value.url
            @request_bindings = value.request_bindings.clone
            @stages = (value.stages || {}).clone
            @params = (value.params || {}).clone
        end
    end

    def [](name)
        @params[name]
    end

    def []=(name, value)
        @params[name] = value
    end

    def invoke(params, &block)
        path, query = bind_request_params @url.path, params
        headers = nil
        # TODO:
        #   Proxy address/port.
        #   User name/password.
        #   Request timeout.
        #   SSL yes/no, timeout.
        #   All other headers
        response = Net::HTTP.start @url.host, @url.port do |http|
            http.request_get("#{path}?#{query}", headers, &block)
        end
        res_context = ResponseContext.new response.body
        process_response res_context
        return res_context.object
    end


    def bind_request(map)
        @request_bindings ||= {}
        map.each do |name, binding|
            if binding.is_a?(String) || binding.is_a?(Symbol)
                binding = {
                    :name=>name,
                    :type=>binding
                }
            elsif !binding.is_a?(Hash)
                raise ArgumentError, "Binding for #{name} not a type (String) or hash"
            end
            @request_bindings[name] = binding
        end
    end


    def bind_request_params(path, params)
        params = @params.merge(params)
        data = nil
        @request_bindings.each do |name, binding|
            value = params[name]
            case binding[:type]
            when :path
                path.gsub! "$#{binding[:name]}$", value
            when :data
                data ||= {}
                data[binding[:name].to_s] = value.to_s
            end
        end
        if data
            data = data.map { |name, value| "#{urlencode(name)}=#{urlencode(value)}" }.join('&')
        end
        [path, data]
    end


    def urlencode(url)
        url.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end


    RESPONSE_STAGES = [ :binding ]

    def add_response_handler(stage, &block)
        stage = stage.to_sym
        raise ArgumentError, "Response handler must be a block" unless block
        @stages ||= {}
        @stages[stage] ||= []
        @stages[stage] << block
    end


    def response_as_json(&block)
        if block
            add_response_handler(:binding) do |response|
                object = JSON::load(response.body)
                block.call(object)
                response.object = object
            end
        else
            add_response_handler(:binding) { |response| response.object = JSON::load(response.body) }
        end
    end

private

    def process_response(response)
        return unless @stages
        RESPONSE_STAGES.each do |stage|
            handlers = @stages[stage]
            if handlers
                handlers.each { |handler| handler.call response }
            end
        end
    end


    class ResponseContext

        attr_accessor :body, :object

        def initialize(body)
            @body = body
        end

    end

end

=begin
# "http://api.search.yahoo.com/ImageSearchService/V1/imageSearch?appid=YahooDemo&query=Madonna&results=2&output=json"

# Create a proxy representing the Yahoo Search API using JSON output
yahoo_search = WebCall.new "http://api.search.yahoo.com/ImageSearchService/V1/$method$"
yahoo_search.bind_request :method=>:path, :appid=>:data, :output=>:data
yahoo_search[:appid] = "YahooDemo"
yahoo_search[:output] = "json"
yahoo_search.response_as_json
# Create a proxy representing a Yahoo Image Search request
yahoo_image_search = WebCall.new yahoo_search
yahoo_image_search.bind_request :query=>:data, :results=>:data
yahoo_image_search[:method] = "imageSearch"
# Make a search request and output the result object
response = yahoo_image_search.invoke :query=>"Madonna", :results=>"2"
puts JSON::dump(response, nil, 4)
=end



# TODO: support for sessions/cookies, and setting session in the object.
# TODO: move method bindings into service bindings.
# TODO: request binding. maybe we need to store the bindings before
#  applying them, e.g. when binding method name with target :default.


module WebClient


    module Binding


        # Base class for service and method bindings.
        #
        # Bindings define how to perform a method call using an HTTP request.
        # Specifically they define which URL to use, how to map arguments into
        # the HTTP request and how to map the HTTP response into a result object
        # or an exception.
        class Base

            # List of supported HTTP methods by their symbol.
            HTTP_METHODS = [ :get, :post ]

            # List of targets for binding input values. See bind_input.
            INPUT_TARGETS = [ :path, :query, :post, :header, :default, :cookie ]

            # List of sources for binding output values. See bind_output.
            OUTPUT_SOURCES = [ :url, :header, :body, :cookie ]


            # The service URL. You can set this in the service bindings, or
            # individual method bindings.
            attr_accessor :url


            # The HTTP method to use. You can set this in the service bindings,
            # or individual method bindings.
            #
            # Valid HTTP methods are <tt>:get</tt> and <tt>:post</tt>. See
            # HTTP_METHODS.
            attr_accessor :http_method


            def initialize(parent = nil, *args, &block)
                @parent = parent
                # If the last argument is a hash, we use its values to call the
                # various set methods.
                arg = args.shift
                if arg.instance_of?(Hash)
                    arg.each_pair do |key, value|
                        method = "#{key}=".to_s
                        raise ArgumentError, "Service bindings do not havea setting for #{key}" unless self.respond_to?(method)
                        self.send(method, value)
                    end
                    arg = args.shift
                end
                raise ArgumentError, "I don't know what to do with the argument #{arg.to_s}" if !arg.nil?

                # If we have a block, we execute the block in order to specify
                # the bindings.
                block.call(self) if block
            end


            # The input values. These input values are mapped to the HTTP request
            # (see bind_inputs).
            #
            # You may want to specify input values that are automatically passed in
            # the request, without requiring them as method arguments, or use default
            # values. For example:
            #  class MyService
            #    include WebClient
            #
            #    service.url = "http://www.example.com/$method$"
            #
            #    method :do_something do
            #      inputs[:method] = "do_something"
            #    end
            #  end
            def inputs
                @inputs ||= {}
            end


            # Convenience method that sets input values from a hash.
            #
            # For example:
            #  inputs = {:method=>"do_something"}
            def inputs=(hash)
                inputs = (@inputs ||= {})
                hash.each_pair { |name, value| @inputs[name.to_sym] = value }
            end


            # Specify how to bind input values to the request message.
            #
            # You can call this method with a list of input names, which will
            # be bound to the target :default. You can also call this method
            # with a hash of input names and their bound targets.
            #
            # Available targets include:
            #  * :path -- Bind the input value to the URL path, replacing part
            #    of the path with the pattern $name$
            #  * :query -- Bind the input value to the URL query string.
            #  * :post -- Bind the input value to content of the HTTP request.
            #    Only valid when using the HTTP method POST.
            #  * :cookie -- Bind the input value to a cookie with the same name.
            #  * :header -- Bind the input value to an HTTP header.
            #  * :default -- Bind the input value to the URL path, if it contains
            #    the pattern $name$. Otherwise, bind it to the HTTP request when
            #    using HTTP POST, or to the URL query string when using HTTP GET.
            #
            # For example:
            #  bind_inputs :method, :param1  # Automagic
            #  bind_inputs :method=>:path, :param1=>:post
            def bind_input(*args)
                bindings = (@input_bindings ||= {})
                args.each do |arg|
                    case arg
                    when String
                        bindings[arg.to_sym] = :default
                    when Symbol
                        bindings[arg] = :default
                    when Hash
                        arg.each_pair do |name, target|
                            # TODO: validate target.
                            bindings[name.to_sym] = target
                        end
                    else
                        raise ArgumentError, "Expecting a list of inputs names, or a hash"
                    end
                end
            end

            alias :bind_input= :bind_input


            # Specify how to bind output values from the response message.
            #
            # You can call this method with a list of output names, which will
            # be bound to the source according to the output name. You can also
            # call this method with a hash of output names and their bound source.
            #
            # Available source include:
            #  * :url -- Bind the output value from the actual URL. You can use
            #    this to capture the request URL, or a redirect.
            #  * :header -- Bind the output value from an HTTP header.
            #  * :cookie -- Bind the output value from a cookie with the same name.
            #  * :body -- Bind the output value from the HTTP response body.
            #
            # If the source is not specified, then the output name :url is always
            # bound to the actual URL, the output name :body is always bound to the
            # HTTP response body, and all other output names are bound to HTTP headers.
            #
            # For example:
            #  bind_output :url, :body # Automagic
            #  bind_inputs :content-type=>:header, :text=>:body
            def bind_output(*args)
                bindings = (@output_bindings ||= {})
                args.each do |arg|
                    case arg
                    when String
                        arg = arg.to_sym
                        bindings[arg] = (arg == :url ? :url : (arg == :body ? :body : :header))
                    when Symbol
                        bindings[arg] = (arg == :url ? :url : (arg == :body ? :body : :header))
                    when Hash
                        arg.each_pair do |name, sorce|
                            # TODO: validate target.
                            bindings[name.to_sym] = source
                        end
                    else
                        raise ArgumentError, "Expecting a list of output names, or a hash"
                    end
                end
            end

            alias :bind_output= :bind_output


            # Create an HTTP request based on the bindings and inputs passed
            # from the method arguments. We also pass the object, so we can get
            # state information (e.g. from sessions) from object variables.
            def create_request(inputs, object)
                # Assemble all the inputs from this binding and any parent binding
                # (typically for method and then for service). Do not overwrite values
                # passed from the method. This is required here so we can use the parent
                # bindings and child input values, e.g. the service may specify binding
                # for method name, but the method specifies the input value.
                set_inputs(inputs, object)
                # Create a request object. If we have parent bindings (e.g. this is a
                # method and the parent is a service), have it construct the request
                # object and populate it first, then override any specific values.
                request = if @parent
                    @parent.create_request(inputs, object)
                else
                    CallContext::Request.new(inputs)
                end
                # If we have any input bindings, we apply them now. We can do this
                # safely since the parent has already collected inputs from the children,
                # and the child bindings can override the parent bindings.
                bind_inputs(request, inputs, object)
                # Return the request object all bound and ready to go.
                request
            end


            # Set input values. Called when creating the HTTP request to establish
            # which input values to bind. This method is called on the child bindings
            # before calling the parent bindings. Make sure to not override child
            # inputs with parent inputs.
            def set_inputs(inputs, object)
                if @inputs
                    @inputs.each do |name, value|
                        name = name.to_sym
                        inputs[name] = value unless inputs.has_key?(name)
                    end
                end
            end


            alias :_set_inputs :set_inputs
            private :_set_inputs

            # Convenience method for changing the behavior of set_inputs. For example:
            #  service do
            #    on_set_inputs do |inputs, object|
            #      inputs[:random] = rand()
            #    end
            #  end
            # Using this method guarantees that the default implementation is called first.
            def on_set_inputs(&block)
                raise ArgumentError, "Missing block" unless block
                define_method(:set_inputs) do |inputs, object|
                    _set_inputs(inputs, object)
                    block.call(inputs, object)
                end
            end


            # Bind input values to the HTTP request. Called after the inputs were established
            # in order to bind them to the HTTP request object. This method is called on the
            # parent binding, and then on the child binding, possibly overriden changes made
            # by the parent binding.
            def bind_inputs(request, inputs, object)
                # Set the request URL and HTTP method, if specified for this bindings.
                request.url = @url if @url
                request.http_method = @http_method if @http_method
                if @input_bindings
                    @input_bindings.each do |name, target|
                        if inputs.has_key?(name)
                            request.bind(name, target, inputs[name])
                        else
                            request.bind(name, target, object.instance_variable_get("@#{name}".to_sym))
                        end
                    end
                end
            end


            alias :_bind_inputs :bind_inputs
            private :_bind_inputs

            # Convenience method for changing the behavior of bind_inputs. For example:
            #  service do
            #    bind_inputs do |request, inputs, object|
            #      request.url = object.url
            #    end
            #  end
            # Using this method guarantees that the default implementation is called first.
            def on_bind_inputs(&block)
                raise ArgumentError, "Missing block" unless block
                define_method(:bind_inputs) do |request, inputs, object|
                    _bind_inputs(request, inputs, object)
                    block.call(request, inputs, object)
                end
            end




            # TODO: Under-developed, needs more work!

            def response_as_json
               # TODO: implement.
            end

            def unwrap_response(response, object)
                begin
                    response.object = to_object(response) unless response.object
                    @parent.unwrap_response(response, object) if @parent
                rescue Exception=>error
                    response.error = error
                end
                response
            end

            def to_object(response)
                response.body
            end

        protected

            def has_binding(name)
                return true if @input_bindings && @input_bindings[name.to_s]
                return @parent.has_binding(name) if @parent
                false
            end

        end


        class Service < Base

            # Create new service bindings.
            #
            # You can initialize the service bindings inline by passing a block,
            # for example:
            #   Service.new do |bindings|
            #     bindings.url = "http://www.example.com"
            #     bindings.http_method = :get
            #   end
            #
            # You can also pass service bindings information as a hash, for example:
            #   Service.new :url=>"http://www.example.com", :http_method=>:get
            #
            # If the first argument is a string, it is interpreted as the service
            # URL. If the second argument is a symbol, it is interpreted as the HTTP
            # method.
            #
            # :call-seq:
            #   Service.new([bindings])
            #   Service.new(url [,bindings])
            #   Service.new(url, http_method [,bindings])
            #   Service.new { |bindings| ... }
            #
            def initialize(*args, &block)
                # If the first argument is a string, it specifies the service URL.
                if args.length > 0 && args[0].instance_of?(String)
                    self.url = args.shift
                    # If the next argument is a symbol, it specifies the HTTP method.
                    if args.length > 0 && args[0].instance_of?(Symbol)
                        self.http_method = args.shift
                    end
                end
                super(nil, *args, &block)
            end

            public :initialize


            def method(name, *args, &block)
                methods = (@methods ||= {})
                if method = methods[name.to_sym]
                    method.initialize(self, name, *args, &block)
                    method
                else
                    methods[name.to_sym] = Method.new(self, name, *args, &block)
                end
            end


            def methods=(map)
                map.each do |method, bindings|
                    method(method, bindings)
                end
            end

        end


        class Method < Base

            def initialize(parent, name, *args, &block)
                # We expect a list of arguments specifying the method arguments (Symbols),
                # and one last optional argument providing more information (Hash).
                while args.length > 0 && args[0].instance_of?(Symbol)
                    self.arguments = args.shift
                end
                super(parent, *args, &block)
                # Bind method name as parameter.
                inputs[:method] = name.to_s unless inputs.has_key?(:method)
            end

            public :initialize


            def arguments
                @arguments ||= []
            end


            def arguments=(*args)
                @arguments ||= []
                @input_bindings ||= {}
                args.each do |arg|
                    case arg
                    when Symbol
                        @arguments << {:name=>arg}
                        @input_bindings[arg.to_sym] = :default unless has_binding(arg)
                    when Array
                        arg.each do |arg|
                            @arguments << {:name=>arg}
                            @input_bindings[arg.to_sym] = :default unless has_binding(arg)
                        end
                    when Hash
                        # TODO: sanity check: we need at least name, default everything else.
                        @arguments << {:name=>arg[:name]}
                        @input_bindings[arg.to_sym] = arg[:target] unless has_binding(arg)
                    else
                        raise ArgumentError
                    end
                end
            end

        end

    end


    module CallContext

        class Request

            attr_accessor :http_method

            def initialize(inputs)
                @inputs = inputs || {}
            end

            def url=(url)
                @url = URI.parse(url)
            end

            def url
                @url
            end

            def in_path(name, value)
                # TODO: encode value
                raise RuntimeError, "Cannot set path part of URL: URL not specified" unless @url
                @url.path.gsub!("$#{name}$", value)
            end

            def in_query(name, value)
                # TODO: encode name/value
                raise RuntimeError, "Cannot set query string part of URL: URL not specified" unless @url
                if @url.query
                    @url.query << "&#{name}=#{value}"
                else
                    @url.query = "#{name}=#{value}"
                end
            end

            def data
                @data ||= {}
            end

            def headers
                @headers ||= {}
            end

            def cookies
                @cookies ||= {}
            end

            def bind(name, target, value)
                case target
                when :path
                    in_path name, value
                when :query
                    in_query name, value
                when :data
                    data[name] = value
                when :headers
                    headers[name] = value
                when :cookie
                    cookies[name] = value
                when :default
                    # TODO: encode value
                    unless @url.path.gsub!("$#{name}$", value)
                        if http_method == :post
                            data[name] = value
                        else
                            in_query name, value
                        end
                    end
                else
                    raise RuntimeError
                end
            end

        end


        class Response

            attr_accessor :body, :object, :error
            attr_reader :code, :status, :headers

            def initialize(http_response)
                @body = http_response.body
                # TODO:
            end

        end

    end


    def service(*args, &block)
        # Create new service bindings if don't already exist, otherwise,
        # modify existing service bindings. Make sure we return the service
        # bindings to the caller.
        if bindings = @service_bindings
            bindings.initialize(*args, &block)
            bindings
        else
            @service_bindings = Binding::Service.new(*args, &block)
        end
    end


    def method(name, *args, &block)
        service = (@service_bindings ||= Binding::Service.new())
        binding = service.method(name, *args, &block)

        # Define a method to proxy the call.
        define_method(name.to_sym) do |*args|
            # TODO: add support for asynchronous callbacks
            #raise ArgumentError, "Not supported yet" if block_given?
            # Create a request context and use the bindings to populate it.
            inputs = {}
            # TODO: verify we don't have too many arguments.
            binding.arguments.each_with_index do |arg, idx|
                value = args[idx]
                inputs[arg[:name]] = value
            end
            request = binding.create_request(inputs, self)
            # TODO: handle all other HTTP methods
            # TODO: handle asynchronous processing
            # TODO: handle cookies
            # TODO: possibly move request creation to request object
            url = request.url
            response = Net::HTTP.start url.host, url.port do |http|
                http.request_get("#{url.path}?#{url.query}", request.headers)
            end
            response = binding.unwrap_response(CallContext::Response.new(response), self)
            raise response.error, caller if response.error
            response.object
        end

        # Return the binding, allowing more method calls.
        binding
    end

    def self.included(mod)
        mod.extend(self)
    end


    class Base

    end

end




# "http://api.search.yahoo.com/ImageSearchService/V1/imageSearch?appid=YahooDemo&query=Madonna&results=2&output=json"

# The programatic way:
puts "Create YahooSearchProgram"
class YahooSearchProgram

    include WebClient

    # Define the service by calling methods on the binding defintion.
    service do |binding|
        # Set the service URL and HTTP method.
        binding.url =  "http://api.search.yahoo.com/ImageSearchService/V1/$method$"
        binding.http_method = :get
        # Bind the input parameters, and specify default inputs.
        binding.bind_input :method=>:path, :appid=>:query, :output=>:query
        binding.inputs[:appid] = "YahooDemo"
        binding.inputs[:output] = "json"
        # Specify that the output is a JSON object.
        binding.response_as_json
    end

    method :imageSearch do |binding|
        # Bind input parameters for this method, and specify default input for the
        # method name (bound by the service).
        binding.bind_input :query=>:query, :results=>:query
        binding.inputs[:method] = "imageSearch"
        binding.arguments = :query, :results
    end

end


# The parameterized version:
puts "Create YahooSearchParam"
class YahooSearchParam

    include WebClient

    # Specify the service URL and HTTP method. Bindings for the inputs, and
    # default values for the inputs. These will modify the URL path and create
    # the URL query string.
    service({
        :url => "http://api.search.yahoo.com/ImageSearchService/V1/$method$",
        :http_method => :get,
        :bind_input => {:method=>:path, :appid=>:query, :output=>:query},
        :inputs => {:appid=>"YahooDemo", :output=>"json"}
    })
    # Specify that the output is a JSON object.
    service.response_as_json

    # Specify a method called imageSearch, it's input parameters, and their bindings
    # to the URL query string. The method parameter (bound for the service) is set to
    # the method name.
    method :imageSearch, {
        :arguments => [:query, :results], # make next two lines irrelevant
        :inputs => {:method=>"imageSearch"}
    }

end


# The automagic version:
puts "Create YahooSearchAutomagic"
class YahooSearchAutomagic

    include WebClient

    # Figure out there's a required parameter 'method' bound to the URL path.
    # The default HTTP method is GET, we just need to specify JSON as output.
    service "http://api.search.yahoo.com/ImageSearchService/V1/$method$?appid=YahooDemo&output=json"
    service.response_as_json

    # Since the HTTP method is GET, arguments are by default bound to the URL query string.
    # The method name is used as the method input
    method :imageSearch, :query, :results

end


client = YahooSearchProgram.new
puts "Call YahooSearchProgram"
pp(client.imageSearch("Madonna", "2"))
puts "Call YahooSearchParam"
client = YahooSearchParam.new
pp(client.imageSearch("Madonna", "2"))
puts "Call YahooSearchAutomagic"
client = YahooSearchAutomagic.new
pp(client.imageSearch("Madonna", "2"))


