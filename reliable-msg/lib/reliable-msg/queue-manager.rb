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

    class Config #:nodoc:

        CONFIG_FILE = "queues.cfg"

        DEFAULT_STORE = MessageStore::Disk::DEFAULT_CONFIG

        DEFAULT_DRB = {
            "port"=>Queue::DRB_PORT,
            "acl"=>"allow 127.0.0.1"
        }

        def initialize file, logger = nil
            @logger = logger
            # If no file specified, attempt to look for file in current directory.
            # If not found in current directory, look for file in Gem directory.
            unless file
                file = if File.exist?(CONFIG_FILE)
                    CONFIG_FILE
                else
                    file = File.expand_path(File.join(File.dirname(__FILE__), '..'))
                    File.basename(file) == 'lib' ? File.join(file, '..', CONFIG_FILE) : File.join(file, CONFIG_FILE)
                end
            end
            @file = File.expand_path(file)
            @config = {}
        end

        def load_no_create
            if File.exist?(@file)
                @config= {}
                File.open @file, "r" do |input|
                    YAML.load_documents input do |doc|
                        @config.merge! doc
                    end
                end
                true
            end
        end

        def load_or_create
            if File.exist?(@file)
                @config= {}
                File.open @file, "r" do |input|
                    YAML.load_documents input do |doc|
                        @config.merge! doc
                    end
                end
                @logger.info "Loaded queues configuration from: #{@file}"
            else
                @config = {
                    "store" => DEFAULT_STORE,
                    "drb" => DEFAULT_DRB
                }
                save
                @logger.info "Created queues configuration file in: #{@file}"
            end
        end

        def create_if_none
            if File.exist?(@file)
                false
            else
                @config = {
                    "store" => DEFAULT_STORE,
                    "drb" => DEFAULT_DRB
                }.merge(@config)
                save
                true
            end
        end

        def exist?
            File.exist?(@file)
        end

        def path
            @file
        end

        def save
            File.open @file, "w" do |output|
                YAML::dump @config, output
            end
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

        ERROR_SEND_MISSING_QUEUE = "You must specify a destination queue for the message" #:nodoc:

        ERROR_RECEIVE_MISSING_QUEUE = "You must specify a queue to retrieve the message from" #:nodoc:

        ERROR_INVALID_HEADER_NAME = "Invalid header '%s': expecting the name to be a symbol, found object of type %s" #:nodoc:

        ERROR_INVALID_HEADER_VALUE = "Invalid header '%s': expecting the value to be %s, found object of type %s" #:nodoc:

        ERROR_NO_TRANSACTION = "Transaction %s has completed, or was aborted" #:nodoc:

        def initialize options = nil
            options ||= {}
            # Locks prevent two transactions from seeing the same message. We use a mutex
            # to ensure that each transaction can determine the state of a lock before
            # setting it.
            @mutex = Mutex.new
            @locks = {}
            # Transactions use this hash to hold all inserted messages (:inserts), deleted
            # messages (:deletes) and the transaction timeout (:timeout) until completion.
            @transactions = {}
            @logger = options[:logger] || Logger.new(STDOUT)
            @config = Config.new options[:config], @logger
        end

        def start
            @mutex.synchronize do
                return if @started

                # Get the message store based on the configuration, or default store.
                @store = MessageStore::Base.configure(@config.store || Config::DEFAULT_STORE, @logger)
                @logger.info "Using message store #{@store.type}"
                @store.activate

                # Get the DRb URI from the configuration, or use the default. Create a DRb server.
                drb = Config::DEFAULT_DRB
                drb.merge(@config.drb) if @config.drb
                drb_uri = "druby://localhost:#{drb['port']}"
                @drb_server = DRb::DRbServer.new drb_uri, self, :tcp_acl=>ACL.new(drb["acl"].split(" "), ACL::ALLOW_DENY), :verbose=>true
                @logger.info "Accepting requests at '#{drb_uri}'"

                # Create a background thread to stop timed-out transactions.
                @timeout_thread = Thread.new do
                    begin
                        while true
                            time = Time.new.to_i
                            @transactions.each_pair do |tid, tx|
                                if tx[:timeout] <= time
                                    begin
                                        @logger.warn "Timeout: aborting transaction #{tid}"
                                        abort tid
                                    rescue
                                    end
                                end
                            end
                            sleep TX_TIMEOUT_CHECK_EVERY
                        end
                    rescue Exception=>error
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

                # Prevent transactions from timing out while we take down the server.
                @timeout_thread.terminate
                # Shutdown DRb server to prevent new requests from being processed.
                drb_uri = @drb_server.uri
                @drb_server.stop_service
                # Deactivate the message store.
                @store.deactivate
                @store = nil
                @drb_server = @store = @timeout_thread = nil
                @logger.info "Stopped queue manager at '#{drb_uri}'"
            end
        end

        def alive?
            @drb_server && @drb_server.alive?
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
            @logger.warn "Transaction #{tid} aborted"
        end

    private
        def integer value, minimum, default
            return default unless value
            value = value.to_i
            value > minimum ? value : minimum
        end

    end

end
