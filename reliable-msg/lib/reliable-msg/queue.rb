#
# = queue.rb - Reliable queue
#
# Author:: Assaf Arkin assaf.arkin@gmail.com
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubySteps
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: Creative Commons Attribution-ShareAlike
#
#--
# Changes:
#++

require 'drb'
require 'rubysteps/queues/selector'


module RubySteps

    # Use the Queue object to put messages in queues, or get messages from queues.
    #
    # You can create a Queue object that connects to a single queue by passing the
    # queue name to the initialized. You can also access other queues by specifying
    # the destination queue when putting a message, or selecting from a queue when
    # retrieving the message.
    #
    # For example:
    #   queue = Queue.new 'my-queue'
    #   # Put a message in the queue with priority 2, expiring in 30 seconds.
    #   msg = 'lorem ipsum'
    #   mid = queue.put msg, :priority=>2, :expires=>30
    #   # Retrieve and process a message from the queue.
    #   queue.get do |msg|
    #     if msg.id == mid
    #       print "Retrieved same message"
    #     end
    #     print "Message text: #{msg.object}"
    #   end
    #
    # See Queue.get and Queue.put for more examples.
    class Queue

        PACKAGE = "RubySteps Queues"

        VERSION = '1.0.9'

        ERROR_INVALID_SELECTOR = 'Selector must be message identifier (String), set of header name/value pairs (Hash), or nil' # :nodoc:

        ERROR_INVALID_TX_TIMEOUT = 'Invalid transaction timeout: must be a non-zero positive integer' # :nodoc:

        ERROR_INVALID_CONNECT_COUNT = 'Invalid connection count: must be a non-zero positive integer' # :nodoc:

        ERROR_SELECTOR_VALUE_OR_BLOCK = 'You can either pass a Selector object, or use a block' # :nodoc:

        # The default DRb port used to connect to the queue manager.
        DRB_PORT = 6438

        DEFAULT_DRB_URI = "druby://localhost:#{DRB_PORT}" #:nodoc:

        # The name of the dead letter queue (<tt>DLQ</tt>). Messages that expire or fail
        # to process are automatically sent to the dead letter queue.
        DLQ = DEAD_LETTER_QUEUE = 'dlq'

        # Number of times to retry a connecting to the queue manager.
        DEFAULT_CONNECT_RETRY = 5

        # Default transaction timeout.
        DEFAULT_TX_TIMEOUT = 120

        # Default number of re-delivery attempts.
        DEFAULT_MAX_RETRIES = 4;

        # Thread.current entry for queue transaction.
        THREAD_CURRENT_TX = :rubysteps_queue_tx #:nodoc:

        # DRb URI for queue manager. You can override this to change the URI globally,
        # for all Queue objects that are not instantiated with an alternative URI.
        @@drb_uri = DEFAULT_DRB_URI

        # Reference to the local queue manager. Defaults to a DRb object, unless
        # the queue manager is running locally.
        @@qm = nil #:nodoc:

        # Cache of queue managers referenced by their URI.
        @@qm_cache = {} #:nodoc:

        # The optional argument +queue+ specifies the queue name. The application can
        # still put messages in other queues by specifying the destination queue
        # name in the header, or get from other queues by specifying the queue name
        # in the selector.
        #
        # TODO: document options
        # * :expires
        # * :priority
        # * :max_retries
        # * :selector
        # * :drb_uri
        # * :tx_timeout
        # * :connect_count
        #
        # :call-seq:
        #   Queue.new([name [,options]])    -> queue
        #
        def initialize queue = nil, options = nil
            options.each do |name, value|
                instance_variable_set "@#{name.to_s}".to_sym, value
            end if options
            @queue = queue
        end

        # Put a message in the queue.
        #
        # The +message+ argument is required, but may be +nil+
        #
        # Headers are optional. Headers are used to provide the application with additional
        # information about the message, and can be used to retrieve messages (see Queue.put
        # for discussion of selectors). Some headers are used to handle message processing
        # internally (e.g. <tt>:priority</tt>, <tt>:expires</tt>).
        #
        # Each header uses a symbol for its name. The value may be string, numeric, true/false
        # or nil. No other objects are allowed. To improve performance, keep headers as small
        # as possible.
        #
        # The following headers have special meaning:
        # * <tt>:delivery</tt> -- The message delivery mode.
        # * <tt>:queue</tt> -- Puts the message in the named queue. Otherwise, uses the queue
        #   specified when creating the Queue object.
        # * <tt>:priority</tt> -- The message priority. Messages with higher priority are
        #   retrieved first.
        # * <tt>:expires</tt> -- Message expiration in seconds. Messages do not expire unless
        #   specified. Zero or +nil+ means no expiration.
        # * <tt>:expires_at</tt> -- Specifies when the message expires (timestamp). Alternative
        #   to <tt>:expires</tt>.
        # * <tt>:max_retries</tt> -- Maximum number of attempts to re-deliver message, afterwhich
        #   message moves to the DLQ. Minimum is 0 (deliver only once), default is 4 (deliver
        #   up to 5 times).
        #
        # Headers can be set on a per-queue basis when the Queue is created. This only affects
        # messages put through that Queue object.
        #
        # Messages can be delivered using one of three delivery modes:
        # * <tt>:best_effort</tt> -- Attempt to deliver the message once. If the message expires or
        #   cannot be delivered, discard the message. The is the default delivery mode.
        # * <tt>:repeated</tt> -- Attempt to deliver until message expires, or up to maximum
        #   re-delivery count (see <tt>:max_retries</tt>). Afterwards, move message to dead-letter
        #   queue.
        # * <tt>:once</tt> -- Attempt to deliver message exactly once. If message expires, or
        #   first delivery attempt fails, move message to dead-letter queue.
        #
        # For example:
        #   queue.put request
        #   queue.put notice, :expires=>10
        #   queue.put object, :queue=>'other-queue'
        #
        # :call-seq:
        #   queue.put(message[, headers]) -> id
        #
        def put message, headers = nil
            tx = Thread.current[THREAD_CURRENT_TX]
            # Use headers supplied by callers, or defaults for this queue.
            headers ||= {}
            headers.fetch(:priority, @priority || 0)
            headers.fetch(:expires, @expires)
            headers.fetch(:max_retries, @max_retries || DEFAULT_MAX_RETRIES)
            # Serialize the message before sending to queue manager. We need the
            # message to be serialized for storage, this just saves duplicate
            # serialization when using DRb.
            message = Marshal::dump message
            # If inside a transaction, always send to the same queue manager, otherwise,
            # allow repeated() to try and access multiple queue managers.
            if tx
                return tx[:qm].queue(:message=>message, :headers=>headers, :queue=>(headers[:queue] || @queue), :tid=>tx[:tid])
            else
                return repeated { |qm| qm.queue :message=>message, :headers=>headers, :queue=>(headers[:queue] || @queue) }
            end
        end

        # Get a message from the queue.
        #
        # Call with no arguments to retrieve the next message in the queue. Call with a message
        # identifier to retrieve that message. Call with selectors to retrieve the first message
        # that matches.
        #
        # Selectors specify which headers to match. For example, to retrieve all messages in the
        # queue 'my-queue' with priority 2:
        #   msg = queue.get :queue=>'my-queue', :priority=>2
        # To put and get the same message:
        #   mid = queue.put obj
        #   msg = queue.get mid # or queue.get :id=>mid
        #   assert(msg.obj == obj)
        #
        # More complex selector expressions can be generated using Queue.selector. For example,
        # to retrieve the next message with priority 2 or higher, received in the last 60 seconds:
        #   selector = Queue.selector { priority >= 2 and received > Time.new.to_i - 60 }
        #   msg = queue.get selector
        # You can also specify selectors for a Queue to be used by default for all Queue.get calls
        # on that Queue object. For example:
        #   queue.selector= { priority >= 2 and received > Time.new.to_i - 60 }
        #   msg = queue.get  # default selector applies
        #
        # The following headers have special meaning:
        # * <tt>:id</tt> -- The message identifier.
        # * <tt>:queue</tt> -- Select a message originally delivered to the named queue. Only used
        #   when retrieving messages from the dead-letter queue.
        # * <tt>:retry</tt> -- Specifies the retry count for the message. Zero when the message is
        #   first delivered, and incremented after each re-delivery attempt.
        # * <tt>:created</tt> -- Indicates timestamp (in seconds) when the message was created.
        # * <tt>:received</tt> -- Indicates timestamp (in seconds) when the message was received.
        # * <tt>:expires_at</tt> -- Indicates timestamp (in seconds) when the message will expire,
        #   +nil+ if the message does not expire.
        #
        # Call this method without a block to return the message. The returned object is of type
        # Message, or +nil+ if no message is found.
        #
        # Call this method in a block to retrieve and process the message. The block is called with
        # the Message object, returning the result of the block. Returns +nil+ if no message is found.
        #
        # All operations performed on the queue inside the block are part of the same transaction.
        # The transaction commits when the block completes. However, if the block raises an exception,
        # the transaction aborts: the message along with any message retrieved through that Queue object
        # are returned to the queue; messages put through that Queue object are discarded. You cannot
        # put and get the same message inside a transaction.
        #
        # For example:
        #   queue.put obj
        #   while queue.get do |msg|  # called for each message in the queue,
        #                             # until the queue is empty
        #     ... do something with msg ...
        #     queue.put obj           # puts another message in the queue
        #     true
        #   end
        # This loop will only complete if it raises an exception, since it gets one message from
        # the queue and puts another message in its place. After an exception, there will be at
        # least one message in the queue.
        #
        # Each attempt to process a message increases its retry count. When the retry count
        # (<tt>:retry</tt>) reaches the maximum allowed (<tt>:max_retry</tt>), the message is
        # moved to the dead-letter queue.
        #
        # This method does not block and returns immediately if there is no message in the queue.
        # To continue processing all messages in the queue:
        #   while true  # repeat forever
        #     while true
        #       break unless queue.get do |msg|
        #         ... do something with msg ...
        #         true
        #       end
        #     end
        #     sleep 5     # no messages, wait
        #   end
        #
        # :call-seq:
        #   queue.get([selector]) -> msg or nil
        #   queue.get([selector]) {|msg| ... } -> obj
        #
        def get selector = nil, &block
            tx = old_tx = Thread.current[THREAD_CURRENT_TX]
            # If block, begin a new transaction.
            if block
                tx = {:qm=>qm}
                tx[:tid] = tx[:qm].begin tx_timeout
                Thread.current[THREAD_CURRENT_TX] = tx
            end
            result = begin
                # Validate the selector: nil, string or hash.
                selector = case selector
                    when String
                        {:id=>selector}
                    when Hash, Array, Queues::Selector
                        selector
                    when nil
                        @selector
                    else
                        raise ArgumentError, ERROR_INVALID_SELECTOR
                end
                # If inside a transaction, always retrieve from the same queue manager,
                # otherwise, allow repeated() to try and access multiple queue managers.
                message = if tx
                    tx[:qm].enqueue :queue=>@queue, :selector=>selector, :tid=>tx[:tid]
                else
                    repeated { |qm| qm.enqueue :queue=>@queue, :selector=>selector }
                end
                # Result is either message, or result from processing block. Note that
                # calling block may raise an exception. We deserialize the message here
                # for two reasons:
                # 1. It creates a distinct copy, so changing the message object and returning
                #    it to the queue (abort) does not affect other consumers.
                # 2. The message may rely on classes known to the client but not available
                #    to the queue manager.
                result = if message
                    message = Message.new(message[:id], message[:headers], Marshal::load(message[:message]))
                    block ? block.call(message) : message
                end
            rescue Exception=>error
                # Abort the transaction if we started it. Propagate error.
                qm.abort(tx[:tid]) if block
                raise error
            ensure
                # Resume the old transaction.
                Thread.current[THREAD_CURRENT_TX] = old_tx if block
            end
            # Commit the transaction and return the result. We do this outside the main
            # block, since we don't abort in case of error (commit is one-phase) and we
            # don't retain the transaction association, it completes by definition.
            qm.commit(tx[:tid]) if block
            result
        end

        # Returns the transaction timeout (in seconds).
        #
        # :call-seq:
        #   queue.tx_timeout -> numeric
        #
        def tx_timeout
            @tx_timeout || DEFAULT_TX_TIMEOUT
        end

        # Sets the transaction timeout (in seconds). Affects future transactions started
        # by Queue.get. Use +nil+ to restore the default timeout.
        #
        # :call-seq:
        #   queue.tx_timeout = timeout
        #   queue.tx_timeout = nil
        #
        def tx_timeout= timeout
            if timeout
                raise ArgumentError, ERROR_INVALID_TX_TIMEOUT unless timeout.instance_of?(Integer) and timeout > 0
                @tx_timeout = timeout
            else
                @tx_timeout = nil
            end
        end

        # Returns the number of connection attempts, before operations fail.
        #
        # :call-seq:
        #   queue.connect_count -> numeric
        #
        def connect_count
            @connect_count || DEFAULT_CONNECT_RETRY
        end

        # Sets the number of connection attempts, before operations fail. The minimum is one.
        # Use +nil+ to restore the default connection count.
        #
        # :call-seq:
        #   queue.connect_count = count
        #   queue.connect_count = nil
        #
        def connect_count= count
            if count
                raise ArgumentError, ERROR_INVALID_CONNECT_COUNT unless count.instance_of?(Integer) and count > 0
                @connect_count = count
            else
                @connect_count = nil
            end
        end

        # If called with no block, returns the selector associated with this Queue
        # (see Queue.selector=). If called with a block, creates and returns a new
        # selector (similar to Queue::selector).
        #
        # :call-seq:
        #   queue.selector -> selector
        #   queue.selector { ... } -> selector
        #
        def selector &block
            block ? Queues::Selector.new(&block) : @selector
        end

        # Sets a default selector for this Queue. Affects all calls to Queue.get on this
        # Queue object that do not specify a selector.
        #
        # You can pass a Selector object, a block expression, or +nil+ if you no longer
        # want to use the default selector. For example:
        #   queue.selector= { priority >= 2 and received > Time.new.to_i - 60 }
        #   10.times do
        #     p queue.get
        #   end
        #   queue.selector= nil
        #
        # :call-seq:
        #   queue.selector = selector
        #   queue.selector = { ... }
        #   queue.selector = nil
        #
        def selector= value = nil, &block
            raise ArgumentError, ERROR_SELECTOR_VALUE_OR_BLOCK if (value && block)
            if value
                raise ArgumentError, ERROR_SELECTOR_VALUE_OR_BLOCK unless value.instance_of?(Queues::Selector)
                @selector = value
            elsif block
                @selector = Queues::Selector.new &block
            else
                @selector = nil
            end
        end

        # Create and return a new selector based on the block expression. For example:
        #   selector = Queue.selector { priority >= 2 and received > Time.new.to_i - 60 }
        #
        # :call-seq:
        #   Queue.selector { ... }  -> selector
        #
        def self.selector &block
            raise ArgumentError, ERROR_NO_SELECTOR_BLOCK unless block
            Queues::Selector.new &block
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


    # A message retrieved from the Queue.
    #
    # Provides access to the message identifier, headers and object.
    #
    # For example:
    #   while queue.get do |msg|
    #     print "Message #{msg.id}"
    #     print "Headers: #{msg.headers.inspect}"
    #     print msg.object
    #     true
    #   end
    class Message


        def initialize id, headers, object # :nodoc:
            @id, @object, @headers = id, object, headers
        end

        # Returns the message identifier.
        #
        # :call-seq:
        #   msg.id -> id
        #
        def id
            @id
        end

        # Returns the message object.
        #
        # :call-seq:
        #   msg.object -> obj
        #
        def object
            @object
        end

        # Returns the message headers.
        #
        # :call-seq:
        #   msg.headers -> hash
        #
        def headers
            @headers
        end

    end


end

