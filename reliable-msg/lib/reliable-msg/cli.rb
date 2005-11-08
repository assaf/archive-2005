require 'reliable-msg/queue-manager'

module ReliableMsg

    class CLI #:nodoc:

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
                puts "Usage: queues server"
            end
        end

    end

end