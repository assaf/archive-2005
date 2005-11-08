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


require 'optparse'
require 'rdoc/usage'
require 'reliable-msg/queue-manager'

module ReliableMsg

    class CLI

        def initialize
        end

        def run
            if ARGV.length == 1 && ARGV[0] == 'server'
                manager = QueueManager.new
                manager.start
                begin
                    while true
                        sleep 2
                    end
                rescue Interrupt
                    manager.stop
                end
            else
                puts <<-EOF
Usage:
  queues server

Note: other features not implemented yet.
EOF
            end
        end

    end

end