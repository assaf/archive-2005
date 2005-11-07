require 'rubysteps/queues/queuemanager'

module RubySteps

    module Queues

        class Application #:nodoc:

            def initialize
            end

            def run
                if ARGV.length == 1 && ARGV[0] == 'server'
                    manager = RubySteps::Queues::QueueManager.new
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

end