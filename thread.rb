require 'set'

class Thread

    @@override = {
        :initialize => instance_method(:initialize),
        :exit => instance_method(:exit)
    }

    @@on_completion = Set.new

    def initialize *args, &block
        @@override[:initialize].bind(self).call *args do
            instance_eval *args, &block
            __completion__ true
        end
    end

    def exit
        @@override[:exit].bind(self).call
        __completion__ false
    end

    def on_completion_add listener
        raise ArgumentError, "Listener must respond to method on_completion(thread, successful), or be a proc with arity 2" unless listener.respond_to?(:on_completion) || (listener.respond_to?(:call) && listener.respond_to?(:arity) && listener.arity == 2)
        @@on_completion.add listener
        nil
    end

    def on_completion_remove listener
        @@on_completion.delete listener
        nil
    end

private
    def __completion__ successful
        @@completion.each do |listener|
            begin
                if listener.respond_to?(:on_completion)
                    listener.on_completion self, successful
                else
                    listener.call self, successful
                end
            rescue Exception=>error
                # Log the error?
            end
        end
    end


end

flg_stop = false
t = Thread.new do
    while true
        puts "Thread called"
        sleep 1
#        break if flg_stop
    end
end
puts "New thread: #{t.status}"
t.run
puts "Run called: #{t.status}"
flg_stop = true
puts "Stop called: #{t.status}"
t.wakeup
puts "Wakup called: #{t.status}"
t.exit
puts "Exit called: #{t.status}"
