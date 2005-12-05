#
# = client.rb - Base class for queue/topic API
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/Ruby/ReliableMessaging
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: MIT and/or Creative Commons Attribution-ShareAlike
#
#--
#++

require 'drb'
require 'reliable-msg/selector'


module ReliableMsg

    # Base class for both Queue and Topic client APIs.
    class Client

        ERROR_INVALID_SELECTOR = "The selector must be a message identifier (string), name/value pairs (Hash), Selector object, or nil" # :nodoc:

        ERROR_INVALID_TX_TIMEOUT = "Invalid transaction timeout: must be a non-zero positive integer" # :nodoc:

        ERROR_INVALID_CONNECT_COUNT = "Invalid connection count: must be a non-zero positive integer" # :nodoc:

        ERROR_SELECTOR_VALUE_OR_BLOCK = "You can either pass a Selector object, or use a block" # :nodoc:

        ERROR_INVALID_INIT_OPTION = "Unrecognized initialization option %s: valid options are %s" #:nodoc:

        ERROR_PAYLOAD_NOT_STRING = "A message payload is required and must be a string" #:nodoc:

        # The default DRb port used to connect to the queue manager.
        DRB_PORT = 6438

        DEFAULT_DRB_URI = "druby://localhost:#{DRB_PORT}" #:nodoc:

        # Number of times to retry a connecting to the queue manager.
        DEFAULT_CONNECT_RETRY = 5

        # Default transaction timeout.
        DEFAULT_TX_TIMEOUT = 120

        # Thread.current entry for queue transaction.
        THREAD_CURRENT_TX = :reliable_msg_tx #:nodoc:

        # The name of the dead letter queue (<tt>DLQ</tt>). Messages that expire or fail
        # to process are automatically sent to the dead letter queue.
        DLQ = DEAD_LETTER_QUEUE = "$dlq"

        # DRb URI for queue manager. You can override this to change the URI globally,
        # for all Queue objects that are not instantiated with an alternative URI.
        @@drb_uri = DEFAULT_DRB_URI

        # Reference to the local queue manager. Defaults to a DRb object, unless
        # the queue manager is running locally.
        @@qm = nil #:nodoc:

        # Cache of queue managers referenced by their URI.
        @@qm_cache = {} #:nodoc:

        # Returns the transaction timeout (in seconds).
        def tx_timeout
            @tx_timeout || DEFAULT_TX_TIMEOUT
        end

        # Sets the transaction timeout (in seconds). Affects future transactions started
        # by Queue.get. Use nil to restore the default timeout.
        def tx_timeout= timeout
            if timeout
                raise ArgumentError, ERROR_INVALID_TX_TIMEOUT unless timeout.instance_of?(Integer) and timeout > 0
                @tx_timeout = timeout
            else
                @tx_timeout = nil
            end
        end

        # Returns the number of connection attempts, before operations fail.
        def connect_count
            @connect_count || DEFAULT_CONNECT_RETRY
        end

        # Sets the number of connection attempts, before operations fail. The minimum is one.
        # Use nil to restore the default connection count.
        def connect_count= count
            if count
                raise ArgumentError, ERROR_INVALID_CONNECT_COUNT unless count.instance_of?(Integer) and count > 0
                @connect_count = count
            else
                @connect_count = nil
            end
        end

        # Create and return a new selector based on the block expression. Same as
        # Selector.new. For example:
        #   selector = Queue.selector { priority >= 2 and received > Time.new.to_i - 60 }
        def self.selector &block
            raise ArgumentError, ERROR_NO_SELECTOR_BLOCK unless block
            Selector.new &block
        end

        # Create and return a new selector based on the block expression. Same as
        # Selector.new. For example:
        #   selector = Queue.selector { priority >= 2 and received > Time.new.to_i - 60 }
        def selector & block
            raise ArgumentError, ERROR_NO_SELECTOR_BLOCK unless block
            Selector.new &block
        end

    private

        # Returns the active queue manager. You can override this method to implement
        # load balancing.
        def qm
            if uri = @drb_uri
                # Queue specifies queue manager's URI: use that queue manager.
                @@qm_cache[uri] ||= DRbObject.new(nil, uri)
            else
                # Use the same queue manager for all queues, and cache it.
                # Create only the first time.
                @@qm ||= DRbObject.new(nil, @@drb_uri || DEFAULT_DRB_URI)
            end
        end

        # Called to execute the operation repeatedly and avoid connection failures. This only
        # makes sense if we have a load balancing algorithm.
        def repeated &block
            count = connect_count
            begin
                block.call qm
            rescue DRb::DRbConnError=>error
                warn error
                warn error.backtrace
                retry if (count -= 1) > 0
                raise error
            end
        end

        class << self
        private
            # Sets the active queue manager. Used when the queue manager is running in the
            # same process to bypass DRb calls.
            def qm= qm
                @@qm = qm
            end
        end

    end


    # == Retrieved Message
    #
    # Returned from Queue.get or Topic.get holding the last message retrieved
    # from the queue/topic. Wraps the message identifier, headers and payload.
    #
    # For example:
    #   while queue.get do |msg|
    #     print "Message #{msg.id}"
    #     print "Headers: #{msg[:created]}"
    #     print "Headers: #{msg.headers.inspect}"
    #     print msg.payload
    #     true
    #   end
    class Message

        def initialize id, headers, payload #:nodoc:
            @id, @payload, @headers = id, payload, headers
        end

        # Returns the message identifier.
        #
        # :call-seq:
        #   msg.id -> string
        #
        def id
            @id
        end

        # Returns the message payload.
        #
        # :call-seq:
        #   msg.payload -> string
        #
        def payload
            @payload
        end

        # Returns the message headers.
        #
        # :call-seq:
        #   msg.headers -> hash
        #
        def headers
            @headers
        end

        # Returns the message header.
        #
        # :call-seq:
        #   msg[symbol] -> obj
        #
        def [] symbol
            @headers[symbol]
        end

        # Deprecated, use payload instead.
        def message
            $stderr.puts "#{caller[0]}: warning: Message#message is deprecated; use Message#payload"
            @payload
        end

        def inspect
            string = "{id: #{@id}"
            @headers.each_pair do |name, value|
                unless name==:id
                    case value
                    when String
                        value = value[0..29] << "..." if value.length > 32
                        value = '"' << value.gsub('"', '\"') << '"'
                    when Symbol
                        value = ":#{value.to_s}"
                    end
                    string << ", :#{name}=>#{value}" unless name == :id
                end
            end
            value = @payload.length > 32 ? @payload[0..29] << "..." : @payload
            string << ", payload: \"" << value << "\"}"
        end

    private
        def method_missing symbol, *args, &block
            raise ArgumentError, "Wrong number of arguments (#{args.length} for 0)" unless args.empty?
            @headers[symbol]
        end

    end

end

