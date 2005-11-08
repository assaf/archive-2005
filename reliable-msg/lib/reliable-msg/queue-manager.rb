#
# = queue-manager.rb - Queue manager
#
# Author:: Assaf Arkin assaf.arkin@gmail.com
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubyRM
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: Creative Commons Attribution-ShareAlike
#
#--
# Changes:
#++

require 'singleton'
require 'drb'
require 'drb/acl'
require 'thread'
require 'yaml'
require 'uuid'
require 'reliable-msg/queue'
require 'reliable-msg/message-store'

module ReliableMsg

    class Configuration #:nodoc:

        CONFIGURATION_FILE = "queues.cfg"

        def initialize file, config
            @file = file
            @config = config || {}
        end

        def save
            File.open @file, "w" do |file|
                YAML::dump @config, file
            end
        end

        def Configuration.load file = CONFIGURATION_FILE
            config = {}
            File.exist?(file) and File.open file, "r" do |file|
                YAML.load_documents file do |doc|
                    config.merge! doc
                end
            end
            Configuration.new file, config
        end

        def method_missing symbol, *args
            if symbol.to_s[-1] == ?=
                @config[symbol.to_s[0...-1]] = *args
            else
                @config[symbol.to_s]
            end
        end

    end


    class QueueManager

        TX_TIMEOUT_CHECK_EVERY = 30

        DEFAULT_STORE = "Disk"

        DEFAULT_DRB_ACL = "allow 127.0.0.1"

        ERROR_SEND_MISSING_QUEUE = "You must specify a destination queue for the message" #:nodoc:

        ERROR_RECEIVE_MISSING_QUEUE = "You must specify a queue to retrieve the message from" #:nodoc:

        ERROR_INVALID_HEADER_NAME = "Invalid header '%s': expecting the name to be a symbol, found object of type %s" #:nodoc:

        ERROR_INVALID_HEADER_VALUE = "Invalid header '%s': expecting the value to be %s, found object of type %s" #:nodoc:

        ERROR_NO_TRANSACTION = "Transaction %s has completed, or was aborted" #:nodoc:

        ERROR_INVALID_MESSAGE_STORE = "No or invalid message store configuration" #:nodoc:

        ERROR_INVALID_MESSAGE_STORE_ADAPTER = "No message store adapter '%s' (note: case is not important)" #:nodoc:

        def initialize config = nil
            config ||= {}
            begin
                # Locks prevent two transactions from seeing the same message. We use a mutex
                # to ensure that each transaction can determine the state of a lock before
                # setting it.
                @mutex = Mutex.new
                @locks = {}
                # Transactions use this hash to hold all inserted messages (:inserts), deleted
                # messages (:deletes) and the transaction timeout (:timeout) until completion.
                @transactions = {}
                @configuration = Configuration.load
                @logger = config[:logger]
            rescue Exception=>error
                puts error
                raise error
            end
        end

        def start
            @mutex.synchronize do
                return if @started
                # Get the class used for the message store, followed by any configuration properties
                # intended for that message store.
                store_cls = ReliableMsg::MessageStore
                store_cfg = @configuration.store || {"adapter"=>DEFAULT_STORE}
                raise RuntimeError, ERROR_INVALID_MESSAGE_STORE unless store_cfg && store_cfg["adapter"]
                store_cfg["adapter"].split('::').each do |part|
                    part.downcase!
                    name = store_cls.constants.find { |name| name.downcase == part }
                    raise RuntimeError, format(ERROR_INVALID_MESSAGE_STORE_ADAPTER, part) unless name
                    store_cls = store_cls.const_get name
                end
                @store = store_cls.new @logger, store_cfg
                if @logger
                    @logger.info "Using message store #{store_cfg['adapter']}"
                else
                    warn "#{PACKAGE}: Using message store #{store_cfg['adapter']}"
                end

                # Get the DRb URI (or default) and create a DRb server.
                if @configuration.drb
                    port = @configuration.drb["port"] || Queue::DRB_PORT
                    acl = @configuration.drb["acl"] || DEFAULT_DRB_ACL
                else
                    acl = DEFAULT_DRB_ACL
                    port = Queue::DRB_PORT
                end
                @drb_server = DRb::DRbServer.new "druby://localhost:#{port}", self, :tcp_acl=>ACL.new(acl.split(' '), ACL::ALLOW_DENY), :verbose=>true
                if @logger
                    @logger.info "Accepting requests at 'druby://localhost:#{port}'"
                else
                    warn "#{PACKAGE}: Accepting requests at 'druby://localhost:#{port}'"
                end

                # Create a background thread to stop timed-out transactions.
                @timeout_thread = Thread.new do
                    begin
                        while true
                            time = Time.new.to_i
                            @transactions.each_pair do |tid, tx|
                                if tx[:timeout] <= time
                                    begin
                                        if @logger
                                            @logger.warn "Timeout: aborting transaction #{tid}"
                                        else
                                            warn "#{PACKAGE}: Timeout: aborting transaction #{tid}"
                                        end
                                        abort tid
                                    rescue
                                    end
                                end
                            end
                            sleep TX_TIMEOUT_CHECK_EVERY
                        end
                    rescue Exception=>error
puts 'BLAFKJADFKADJFDAKJ'
                        retry
                    end
                end

                # Associate this queue manager with the local Queue class, instead of using DRb.
                Queue.send :qm=, self
                @started = true
            end
        end

        def stop
            @mutex.synchronize do
                return unless @started
                drb_uri = @drb_server.uri
                @drb_server.stop_service
                @timeout_thread.terminate
                if @logger
                    @logger.info "Stopped queue manager at '#{drb_uri}'"
                else
                    warn "#{PACKAGE}: Stopped queue manager at '#{drb_uri}'"
                end
            end
        end

        def queue args
            # Get the arguments of this call.
            message, headers, queue, tid = args[:message], args[:headers], args[:queue].downcase, args[:tid]
            raise ArgumentError, ERROR_SEND_MISSING_QUEUE unless queue and queue.instance_of?(String) and !queue.empty?
            time = Time.new.to_i
            # TODO: change this to support the RM delivery protocol.
            id = args[:id] || UUID.new
            created = args[:created] || time

            # Validate and freeze the headers. The cloning ensures that the headers we hold in memory
            # are not modified by the caller. The validation ensures that the headers we hold in memory
            # can be persisted safely. Basic types like string and integer are allowed, but application types
            # may prevent us from restoring the index. Strings are cloned since strings may be replaced.
            headers = if headers
                copy = {}
                headers.each_pair do |name, value|
                    raise ArgumentError, format(ERROR_INVALID_HEADER_NAME, name, name.class) unless name.instance_of?(Symbol)
                    case value
                        when String, Numeric, Symbol, true, false, nil
                            copy[name] = value.freeze
                        else
                            raise ArgumentError, format(ERROR_INVALID_HEADER_VALUE, name, "a string, numeric, symbol, true/false or nil", value.class)
                    end
                end
                copy
            else
                {}
            end

            # Set the message headers controlled by the queue.
            headers[:id] = id
            headers[:received] = time
            headers[:delivery] ||= :best_effort
            headers[:retry] = 0
            headers[:max_retries] = integer headers[:max_retries], 0, Queue::DEFAULT_MAX_RETRIES
            headers[:priority] = integer headers[:priority], 0, 0
            if expires_at = headers[:expires_at]
                raise ArgumentError, format(ERROR_INVALID_HEADER_VALUE, :expires_at, "an integer", expires_at.class) unless expires_at.is_a?(Integer)
            elsif expires = headers[:expires]
                raise ArgumentError, format(ERROR_INVALID_HEADER_VALUE, :expires, "an integer", expires.class) unless expires.is_a?(Integer)
                headers[:expires_at] = Time.now.to_i + expires if expires > 0
            end
            # Create an insertion record for the new message.
            insert = {:id=>id, :queue=>queue, :headers=>headers, :message=>message}
            if tid
                tx = @transactions[tid]
                raise RuntimeError, format(ERROR_NO_TRANSACTION, tid) unless tx
                tx[:inserts] << insert
            else
                @store.transaction do |inserts, deletes, dlqs|
                    inserts << insert
                end
            end
            # Return the message identifier.
            id
        end


        def enqueue args
            # Get the arguments of this call.
            queue, selector, tid = args[:queue].downcase, args[:selector], args[:tid]
            id, headers = nil, nil
            raise ArgumentError, ERROR_RECEIVE_MISSING_QUEUE unless queue and queue.instance_of?(String) and !queue.empty?

            # We need to lock the selected message, before deleting, otherwise,
            # we allow another transaction to see the message we're about to delete.
            # This is true whether we delete the message inside or outside a client
            # transaction. We can wrap everything with a mutex, but it's faster to
            # release the locks mutex as fast as possibe.
            message = @mutex.synchronize do
                message = @store.select queue do |headers|
                    not @locks.has_key?(headers[:id]) and case selector
                        when nil
                            true
                        when String
                            headers[:id] == selector
                        when Hash
                            selector.all? { |name, value| headers[name] == value }
                        when Selector
                            selector.__evaluate__ headers
                    end
                end
                if message
                    @locks[message[:id]] = true
                    message
                end
            end
            # Nothing to do if no message found.
            return unless message

            # If the message has expired, or maximum retry count elapsed, we either
            # discard the message, or send it to the DLQ. Since we're out of a message,
            # we call to get a new one. (This can be changed to repeat instead of recurse).
            headers = message[:headers]
            if queue != Queue::DLQ && ((headers[:expires_at] && headers[:expires_at] < Time.now.to_i) || (headers[:retry] > headers[:max_retries]))
                expired = {:id=>message[:id], :queue=>queue, :headers=>headers}
                if headers[:delivery] == :once || headers[:delivery] == :repeated
                    @store.transaction { |inserts, deletes, dlqs| dlqs << expired }
                else # :best_effort
                    @store.transaction { |inserts, deletes, dlqs| deletes << expired }
                end
                @mutex.synchronize { @locks.delete message[:id] }
                return enqueue(args)
            end

            delete = {:id=>message[:id], :queue=>queue, :headers=>headers}
            begin
                if tid
                    tx = @transactions[tid]
                    raise RuntimeError, format(ERROR_NO_TRANSACTION, tid) unless tx
                    if queue != Queue::DLQ && headers[:delivery] == :once
                        # Exactly once delivery: immediately move message to DLQ, so if
                        # transaction aborts, message is not retrieved again. Do not
                        # release lock here, to prevent message retrieved from DLQ.
                        # Change delete record so message removed from DLQ on commit.
                        @store.transaction do |inserts, deletes, dlqs|
                            dlqs << delete
                        end
                        delete[:queue] = Queue::DLQ
                        tx[:deletes] << delete
                    else
                        # At most once delivery: delete message if transaction commits.
                        # Best effort: we don't need to delete on commit, but it's more
                        # efficient this way.
                        # Exactly once: message never gets to expire in DLQ.
                        tx[:deletes] << delete
                    end
                else
                    @store.transaction do |inserts, deletes, dlqs|
                        deletes << delete
                    end
                    @mutex.synchronize { @locks.delete message[:id] }
                end
            rescue Exception=>error
                # Because errors do happen.
                @mutex.synchronize { @locks.delete message[:id] }
                raise error
            end

            # To prevent a transaction from modifying a message and then returning it to the
            # queue by aborting, we instead clone the message by de-serializing (this happens
            # in Queue, see there). The headers are also cloned (shallow, all values are frozen).
            return :id=>message[:id], :headers=>message[:headers].clone, :message=>message[:message]
        end

        def begin timeout
            tid = UUID.new
            @transactions[tid] = {:inserts=>[], :deletes=>[], :timeout=>Time.new.to_i + timeout}
            tid
        end

        def commit tid
            tx = @transactions[tid]
            raise RuntimeError, format(ERROR_NO_TRANSACTION, tid) unless tx
            begin
                @store.transaction do |inserts, deletes, dlqs|
                    inserts.concat tx[:inserts]
                    deletes.concat tx[:deletes]
                end
                # Release locks here, otherwise we expose messages before the
                # transaction gets the chance to delete them from the queue.
                @mutex.synchronize do
                    tx[:deletes].each { |delete| @locks.delete delete[:id] }
                end
                @transactions.delete tid
            rescue Exception=>error
                abort tid
                raise error
            end
        end

        def abort tid
            tx = @transactions[tid]
            raise RuntimeError, format(ERROR_NO_TRANSACTION, tid) unless tx
            # Release locks here because we are no longer in posession of any
            # retrieved messages.
            @mutex.synchronize do
                tx[:deletes].each do |delete|
                    @locks.delete delete[:id]
                    delete[:headers][:retry] += 1
                end
            end
            @transactions.delete tid
            if @logger
                @logger.warn "Transaction #{tid} aborted"
            else
                warn "#{PACKAGE}: Transaction #{tid} aborted"
            end
        end

    private
        def integer value, minimum, default
            return default unless value
            value = value.to_i
            value > minimum ? value : minimum
        end

    end

end
