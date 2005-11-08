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
Usage:
  queues server start?
  queues server stop
  queues install disk <path>?
  queues install mysql <host> <database> <username> <password>

Note: other features not implemented yet.
EOF

        class InvalidUsage  < Exception
        end

        def initialize
        end

        def run
            begin
                raise InvalidUsage if ARGV.length < 1
                case ARGV[0]
                when 'server'
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
                        DRbObject.new(nil, Queue::DEFAULT_DRB_URI).stop
                    else
                        raise InvalidUsage
                    end
                when 'install'
                    case ARGV[1]
                    when 'disk'
                        config = Config.new
                        config.store = MessageStore::Disk.configuration
                        if config.create_if_none
                            store = MessageStore.get config.store
                            store.install
                        end
=begin
                    when 'mysql'
                        config = Config.new
                        host, database, username, password = ARGV[2], ARGV[3], ARGV[4], ARGV[5]
                        raise InvalidUsage unless host && database && username && password
                        config.store = MessageStore::MySQL.configuration(host, database, username, password)
                        if config.create_if_none
                            store = MessageStore.get config.store
                            store.install
                        end
=end
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