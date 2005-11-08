#
# = selector.rb - Deferred expression evaluation selector
#
# Author:: Assaf Arkin assaf.arkin@gmail.com
# Documentation:: http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/RubyRM
# Copyright:: Copyright (c) 2005 Assaf Arkin
# License:: Creative Commons Attribution-ShareAlike
#
# Credit to Jim Weirich who provided the influence. Ideas borrowed from his
# presentation on domain specific languages, and the BlankSlate source code.
#
#--
# Changes:
#++

module ReliableMsg #:nodoc:

    class Selector

            # We're using DRb. Unless we support respond_to? and instance_eval?, DRb will
            # refuse to marshal the selector as an argument and attempt to create a remote
            # object instead.
            instance_methods.each { |name| undef_method name unless name =~ /^(__.*__)|respond_to\?|instance_eval$/ }

            def initialize &block
                # Call the block and hold the deferred value.
                @value = self.instance_eval &block
            end

            def method_missing symbol, *args
                if symbol == :__evaluate__
                    # Evaluate the selector with the headers passed in the argument.
                    @value.is_a?(Deferred) ? @value.__evaluate__(*args) : @value
                else
                    # Create a deferred value for the missing method (a header).
                    raise ArgumentError, "Can't pass arguments to header" unless args.empty?
                    Header.new symbol
                end
            end


        class Deferred #:nodoc:

            # We're using DRb. Unless we support respond_to? and instance_eval?, DRb will
            # refuse to marshal the selector as an argument and attempt to create a remote
            # object instead.
            instance_methods.each { |name| undef_method name unless name =~ /^(__.*__)|respond_to\?|instance_eval$/ }

            def initialize target, operation, args
                @target = target
                @operation = operation
                @args = args
            end

            def coerce value
                [Constant.new(value), self]
            end

            def method_missing symbol, *args
                if symbol == :__evaluate__

                    eval_args = @args.collect { |arg| arg.instance_of?(Deferred) ? arg.__evaluate__(*args) : arg }
                    @target.__evaluate__(*args).send @operation, *eval_args
                else
                    Deferred.new self, symbol, args
                end
            end

        end

        class Header < Deferred #:nodoc:

            def initialize name
                @name = name
            end

            def coerce value
                [Constant.new(value), self]
            end

            def method_missing symbol, *args
                if symbol == :__evaluate__
                    args[0][@name]
                else
                    Deferred.new self, symbol, args
                end
            end

        end

        class Constant < Deferred #:nodoc:

            def initialize value
                @value = value
            end

            def method_missing symbol, *args
                if symbol == :__evaluate__
                    @value
                else
                    Deferred.new self, symbol, args
                end
            end

        end

    end

end
