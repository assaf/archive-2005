class Class

    # :call-seq:
    #   add_redefine(symbol, ...) => self
    #
    # Declares a method that can easily be redefined.
    #
    # For each symbol, if the instance method exists, it adds a redefine
    # method. The redefine method has the name redefine_<source>, and
    # expects a block to use as the new definition.
    #
    # For example:
    #  class Redefine
    #    def test
    #      puts "Original method"
    #    end
    #
    #    add_redefine :test
    #  end
    #
    #  obj = Redefine.new
    #  obj.test
    #  obj.redefine_test { puts "Redefined method" }
    #  obj.test
    #
    # produces
    #  Original method
    #  Redefined method
    #
    def can_redefine(*symbols)
        symbols.each do |symbol|
            # This just complains if the method is not already defined.
            instance_method(symbol)
            class_eval %Q{
             def redefine_#{symbol} (&block)
               class << self
                 self
               end.class_eval { define_method(:#{symbol}, &block) }
             end
           }
        end
        self
    end

end


class Class

    # :call-seq:
    #   fallback(symbol, ...) => self
    #
    # Creates fallback methods for all listed instance methods.
    # Fallback methods are useful when extending objects with new methods
    # (singleton), while still being able to fallback on the functionality
    # provided by the original method.
    #
    # When used in a class, it creates a protected copy of each named
    # method, prefixing the method name with a single underscore.
    #
    # For example:
    #  class Fallback
    #    def test
    #      "The Original Joe"
    #    end
    #    fallback :test
    #  end
    #
    #  fallback = Fallback.new
    #  puts fallback.test
    #  module NewMethods
    #    def test
    #      "Not " << _test()
    #    end
    #  end
    #  fallback.extend NewMethods
    #  puts fallback.test
    #
    # _produces_:
    #  The Original Joe
    #  Not The Original Joe
    #
    def fallback(*symbols)
        symbols.each do |symbol|
            method = instance_method(symbol)
            protected = "_#{symbol.to_s}".to_sym
            define_method(protected, method)
            protected(protected)
        end
        self
    end

end

