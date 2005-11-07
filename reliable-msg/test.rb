$:.unshift File.join(File.dirname(__FILE__), "lib")
require 'queues'
#require_gem 'rubysteps-queues'
#load 'queues'


require 'rubysteps/queues/queuemanager'
manager = RubySteps::Queues::QueueManager.new
manager.start

def benchmark text
    threads = []
    iters = 1000
    5.times do
        queue = RubySteps::Queue.new "test"
        threads << Thread.new do
            begin
                mid = queue.put text
                iters.times do
                    mid = queue.get mid do |msg|
                        queue.put text
                        msg.id
                    end
                end
                queue.get mid
            rescue Exception => error
                p error
                p error.backtrace
            end
        end
    end

    start = Time.new
    threads.each { |thread| thread.run }
    threads.each { |thread| thread.join }
    elapsed = Time.new - start
    p "Threads: #{threads.length}"
    p "Completed in #{elapsed}"
    p "Performed #{iters * threads.length / elapsed}/sec"
end

class AbortTransaction < Exception
end


queue = RubySteps::Queue.new 'test'
# cleanup
while queue.get ; end
mid = queue.put 'my-message'
p "Added message #{mid}"
msg = queue.get mid
p "Retrieved message #{msg.id}"
mid = queue.put 'my-message'
p "Added message #{mid}"
begin
    queue.get mid do |msg|
        raise AbortTransaction
        p "Retrieved message #{msg.id}"
    end
rescue AbortTransaction
end
queue.get queue.selector { id == mid } do |msg|
    p "Retrieved message #{msg.id}"
end

benchmark "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Sed at arcu et wisi laoreet auctor. Proin congue tincidunt enim. Nunc suscipit varius enim. Aenean lorem. Quisque tristique ante at purus. Proin vel ipsum et sem feugiat sollicitudin. Praesent eu tortor. Etiam sit amet nunc. Integer risus orci, sollicitudin vitae, suscipit ultrices, tempor quis, nibh. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Pellentesque sodales. Suspendisse potenti. Nullam wisi arcu, adipiscing ut, ultricies sed, ultricies nec, neque. Donec rhoncus tristique neque."

manager.stop
