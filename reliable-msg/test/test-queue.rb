#
# = test-queue.rb - Queue manager test cases
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubyReliableMessaging
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: MIT and/or Creative Commons Attribution-ShareAlike
#
#--
#++

require 'test/unit'
require 'reliable-msg'

class TestQueue < Test::Unit::TestCase

    class AbortTransaction < Exception
    end

    def setup
        @queue = ReliableMsg::Queue.new 'test-queue'
        @dlq = ReliableMsg::Queue.new ReliableMsg::Queue::DLQ
        @manager = ReliableMsg::QueueManager.new
        @manager.start
        clear
    end

    def teardown
        @manager.stop
        clear
    end

    def test_order
        clear
        # Put two messages, test that they are retrieved in order.
        id1 = @queue.put 'first test message'
        id2 = @queue.put 'second test message'
        msg = @queue.get
        assert msg && msg.id == id1, "Failed to retrieve message in order"
        msg = @queue.get
        assert msg && msg.id == id2, "Failed to retrieve message in order"
        assert @queue.get.nil?, "Phantom message in queue"

        # Put three messages with priority, test that they are retrieved in order.
        id1 = @queue.put 'priority one message', :priority=>1
        id2 = @queue.put 'priority three message', :priority=>3
        id3 = @queue.put 'priority two message', :priority=>2
        msg = @queue.get
        assert msg && msg.id == id2, "Failed to retrieve message in order"
        msg = @queue.get
        assert msg && msg.id == id3, "Failed to retrieve message in order"
        msg = @queue.get
        assert msg && msg.id == id1, "Failed to retrieve message in order"
        assert @queue.get.nil?, "Phantom message in queue"
    end

    def test_selector
        clear
        # Test that we can retrieve message based on specific header value,
        # contrary to queue order.
        id1 = @queue.put 'first test message', :name=>"foo"
        id2 = @queue.put 'second test message', :name=>"bar"
        msg = @queue.get(ReliableMsg::Queue.selector { name == 'bar' })
        assert msg && msg.id == id2, "Failed to retrieve message by selector"
        msg = @queue.get(ReliableMsg::Queue.selector { name == 'foo' })
        assert msg && msg.id == id1, "Failed to retrieve message by selector"
        assert @queue.get.nil?, "Phantom message in queue"
    end

    def test_non_delivered
        clear
        # Test that we can receive message that has not yet expired (30 second delay),
        # but cannot receive message that has expires (1 second, we wait for 2), and
        # that message has been moved to the DLQ.
        id1 = @queue.put 'first test message', :expires=>30, :delivery=>:repeated
        id2 = @queue.put 'second test message', :expires=>1, :delivery=>:repeated
        msg = @queue.get :id=>id1
        assert msg, "Failed to retrieve message that did not expire"
        sleep 2
        msg = @queue.get :id=>id2
        assert msg.nil?, "Incorrectly retrieved expired message"
        msg = @dlq.get
        assert msg && msg.id == id2, "Message not moved to DLQ"

        # Test that we can receive message more than once, but once we try more than
        # max_deliveries, the message moves to the DLQ.
        id1 = @queue.put 'test message', :max_retries=>1, :delivery=>:repeated
        begin
            @queue.get do |msg|
                assert msg && msg.id == id1, "Block called without the message"
                raise AbortTransaction
            end
            flunk "Message not found in queue, or exception not propagated"
        rescue AbortTransaction
        end
        begin
            @queue.get do |msg|
                assert msg && msg.id == id1, "Block called without the message"
                raise AbortTransaction
            end
            flunk "Message not found in queue, or exception not propagated"
        rescue AbortTransaction
        end
        assert @queue.get.nil?, "Incorrectly retrieved expired message"
        msg = @dlq.get
        assert msg && msg.id == id1, "Message not moved to DLQ"

        # Test that message discarded when delivery mode is best_effort.
        id1 = @queue.put 'test message', :max_retries=>0, :delivery=>:best_effort
        begin
            @queue.get do |msg|
                assert msg && msg.id == id1, "Block called without the message"
                raise AbortTransaction
            end
            flunk "Message not found in queue, or exception not propagated"
        rescue AbortTransaction
        end
        assert @queue.get.nil?, "Incorrectly retrieved expired message"
        assert @dlq.get.nil?, "Message incorrectly moved to DLQ"

        # Test that message is moved to DLQ when delivery mode is exactly_once.
        id1 = @queue.put 'test message', :max_retries=>2, :delivery=>:once
        begin
            @queue.get do |msg|
                assert msg && msg.id == id1, "Block called without the message"
                assert @dlq.get.nil?, "Message prematurely found in DLQ"
                raise AbortTransaction
            end
            flunk "Message not found in queue, or exception not propagated"
        rescue AbortTransaction
        end
        assert @queue.get.nil?, "Incorrectly retrieved expired message"
        msg = @dlq.get
        assert msg && msg.id == id1, "Message not moved to DLQ"
    end

private
    def clear
        # Empty test queue and DLQ.
        while @queue.get ; end
        while @dlq.get ; end
    end

end

