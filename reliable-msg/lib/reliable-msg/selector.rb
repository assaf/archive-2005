#
# = selector.rb - Deferred expression evaluation selector
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubyReliableMessaging
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: MIT and/or Creative Commons Attribution-ShareAlike
#
# Credit to Jim Weirich who provided the influence. Ideas borrowed from his
# presentation on domain specific languages, and the BlankSlate source code.
#
#--
#++

module ReliableMsg #:nodoc:

    class Selector

        def initialize &block
            @block = block
            @list = nil
        end


        def select list
            @list = []
            list.each do |headers|
                id = headers[:id]
                context = EvaluationContext.new headers
                @list << id if context.instance_eval(&@block)
            end
        end


        def next
            @list && @list.shift
        end


    end


    class EvaluationContext #:nodoc:

        instance_methods.each { |name| undef_method name unless name =~ /^(__.*__)|instance_eval$/ }


        def initialize headers
            @headers = headers
        end


        def now
            Time.now.to_i
        end


        def method_missing symbol, *args, &block
            if @headers.has_key?(symbol)
                raise ArgumentError, "Wrong number of arguments (#{args.length} for 0)" unless args.empty?
                @headers[symbol]
            else
                super
            end
        end

    end

end
