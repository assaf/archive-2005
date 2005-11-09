#
# = cli.rb - Reliable messaging command-line interface
#
# Author:: Assaf Arkin assaf.arkin@gmail.com
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubyRM
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: Creative Commons Attribution-ShareAlike
#
#--
# Changes:
#++


require 'drb'
require 'optparse'
require 'rdoc/usage'
require 'reliable-msg/queue-manager'

module ReliableMsg

    class CLI

        USAGE = <<-EOF
Start the queue manager as a standalone server
  queues manager start

Stop a queue manager running on this machine
  queues manager stop

Configure the queue manager to use disk-based message store
  queues install disk <path>?

Where <path> points to the directory holding the messages.
By default it creates and uses the directory 'queues'.

Configure the queue manager to use MySQL for message store
  queues install mysql <host> <username> <password> <database>

The following options are also available
  --port    Specify which port to use
  --socket  Specify which socket to use
  --prefix  Specify prefix for database tables (the default
            is reliable_msg_)
EOF

        class InvalidUsage  < Exception
        end

        def initialize
        end

        def run
            begin
                raise InvalidUsage if ARGV.length < 1
                case ARGV[0]
                when 'manager'
                    case ARGV[1]
                    when 'start', nil
                        manager = QueueManager.new
                        manager.start
                        begin
                            while manager.alive?
                                sleep 3
                            end
                        rescue Interrupt
                            manager.stop
                        end
                    when 'stop'
                        drb_uri = Queue::DEFAULT_DRB_URI
                        begin
                            DRbObject.new(nil, drb_uri).stop
                        rescue DRb::DRbConnError =>error
                            puts "No queue manager at #{drb_uri}"
                        end
                    else
                        raise InvalidUsage
                    end

                when 'install'
                    config = Config.new nil, nil
                    case ARGV[1]
                    when 'disk'
                        store = MessageStore::Disk.new({}, nil)
                        config.store = store.configuration
                        if config.create_if_none
                            store.setup
                            puts "Created queues configuration file: #{config.path}"
                        else
                            puts "Found existing queues configuration file: #{config.path}"
                        end
                    when 'mysql'
                        host, username, password, database = ARGV[2], ARGV[3], ARGV[4], ARGV[5]
                        raise InvalidUsage unless host && database && username && password
                        conn = { "host"=>host, "username"=>username, "password"=>password, "database"=>database }
                        store = MessageStore::MySQL.new(conn, nil)
                        config.store = store.configuration
                        if config.create_if_none
                            puts "Created queues configuration file: #{config.path}"
                            if store.setup
                                puts "Created queue manager tables in database '#{database}'"
                            end
                        else
                            puts "Found existing queues configuration file: #{config.path}"
                        end
                    else
                        raise InvalidUsage
                    end
                else
                    raise InvalidUsage
                end
            rescue InvalidUsage
                puts USAGE
            end
        end

    end

end

if __FILE__ == $0
    ReliableMsg::CLI.new.run
end