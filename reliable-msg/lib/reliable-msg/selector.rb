#
# = selector.rb - Deferred expression evaluation selector
#
# Author:: Assaf Arkin  assaf@labnotes.org
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/Ruby/ReliableMessaging
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

        ERROR_INVALID_SELECTOR_BLOCK = "Selector must be created with a block accepting no arguments" #:nodoc:

        # Create a new selector that evaluates by calling the block.
        #
        # :call-seq:
        #   Selector.new { |headers| ... } -> selector
        #
        def initialize &block
            raise ArgumentError, ERROR_INVALID_SELECTOR_BLOCK unless block && block.arity < 1
            @block = block
        end


        # Matches the message headers with the selectors. Returns true
        # if a match is made, false otherwise. May raise an error if
        # there's an error in the expression.
        #
        # :call-seq:
        #   selector.match(headers) -> boolean
        #
        def match headers #:nodoc:
            context = EvaluationContext.new headers
            context.instance_eval(&@block)
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
