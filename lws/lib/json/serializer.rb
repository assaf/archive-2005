require 'stringio'

module JSON

    class Serializer

        # Regular expression for catching all the characters that must be encoded.
        ESCAPE_REGEXP = /[^[:print:]]|["\\\/]/

        # Proc for encoding non-printable characters, quote and back-slash.
        ESCAPE_PROC = Proc.new do |match|
            case match[0]
            when 34
                '\\"'
            when 47
                '\\/'
            when ?\\
                '\\\\'
            when ?\n
                '\\n'
            when ?\r
                '\\r'
            when ?\f
                '\\f'
            when ?\t
                '\\t'
            when ?\b
                '\\b'
            else
                sprintf "\\%04x", match[0]
            end
        end

        DEFAULT_INDENT = 4

        def initialize output = nil, indent = 0, &block
            @separator = false
            @io = output || StringIO.new
            @closed = false
            if indent && indent > 0
                @indent, @indent_by = 1, " " * indent
            else
                @indent, @indent_by = 0, nil
            end
            @io << '{'
            instance_eval &block if block
        end


        def self.indented output = nil, &block
            self.new output, DEFAULT_INDENT, &block
        end


        def flush
            close
            @io.flush
        end


        def to_str
            close
            @io.string
        end

        alias :to_json :to_str


        def write *args, &block
            raise RuntimeError, "Serialized closed for writing" if @closed
            raise ArgumentError, "wrong number of arguments (0 for 1)" unless args.length > 0
            case args[0]
            when Hash, Struct
                raise ArgumentError, "only one hash allowed, no block expected" if args.length > 1 || block
                name, value = nil, nil
                args[0].each_pair do |name, value|
                    @io << ',' if @separator
                    if @indent_by
                        @io << "\n"
                        @indent.times { @io << @indent_by }
                    end
                    name = name.to_s unless name.instance_of?(String)
                    @io << '"' << name.gsub(ESCAPE_REGEXP, &ESCAPE_PROC) << '": '
                    write_value value
                    @separator = true
                end
            when String, Symbol, Numeric
                raise ArgumentError, "expected second argument with value, or a block" unless args.length == 2 || block
                @io << ',' if @separator
                if @indent_by
                    @io << "\n"
                    @indent.times { @io << @indent_by }
                end
                name = name.instance_of?(String) ? args[0] : args[0].to_s
                @io << '"' << name.gsub(ESCAPE_REGEXP, &ESCAPE_PROC) << '": '
                if block
                    separator, @separator = @separator, false
                    @io << '{'
                    if @indent_by
                        @indent += 1
                        instance_eval &block
                        @indent -= 1
                        @io << "\n"
                        @indent.times { @io << @indent_by }
                    else
                        instance_eval &block
                    end
                    @io << '}'
                    @separator = separator
                else
                    write_value args[1]
                end
            else
                raise ArgumentError, "first argument must be values of object (a Hash), or a name/value pair"
            end
            @separator = true
            self
        end


        def object &block
            raise RuntimeError, "Serialized closed for writing" if @closed
            ser = Serializer.new
            ser.instance_variable_set :@indent_by,  @indent_by
            ser.instance_variable_set :@indent,  @indent + 1
            ser.instance_eval &block
            ser
        end

    private

        def write_value value
            case value
            when String
                @io << '"' << value.gsub(ESCAPE_REGEXP, &ESCAPE_PROC) << '"'
            when Numeric
                @io << value.to_s
            when TrueClass
                @io << "true"
            when FalseClass
                @io << "false"
            when NilClass
                @io << "null"
            when Symbol
                @io << '"' << value.to_s << '"'
            when Array
                @io << '['
                separator = false
                item = nil
                value.each do |item|
                    @io << ',' if separator
                    write_value item
                    separator = true
                end
                @io << ']'
            when Hash
                @io << '{'
                separator, @separator = @separator, false
                name = nil
                if @indent_by
                    @indent += 1
                    value.each_pair { |name, value| write name, value }
                    @indent -= 1
                    @io << "\n"
                    @indent.times { @io << @indent_by }
                else
                    value.each_pair { |name, value| write name, value }
                end
                @io << '}'
                @separator = true
            when Serializer
                @io << value.to_str
            else
                if value.respond_to?(:to_json)
                    @io << value.to_json
                else
                    @io << '"' << value.to_s.gsub(ESCAPE_REGEXP, &ESCAPE_PROC) << '"'
                end
            end
        end

        def close
            begin
                # Make sure to close object exactly once for each call to this method.
                unless @closed
                    # Closing indentation, since this may be nested in another object.
                    if @indent_by
                        @indent -= 1
                        @io << "\n"
                        @indent.times { @io << @indent_by }
                    end
                    @io << '}'
                end
            ensure
                @closed = true
            end
        end

    end

end
