require 'strscan'

module JSON

    class ParseError < RuntimeError
    end


    class ObjectBuilder

        def create_root
            {}
        end

        def create_object parent, name
            {}
        end

        def create_array parent, name
            []
        end

        def set_value parent, name, value
            parent[name] = value
        end

    end


    class Parser < ObjectBuilder


        # Regular expression for catching all the characters that must be decoded.
        DECODE_REGEXP = /\\[nrftb\\\/"]|\\\d{4}/

        # Proc for decoding escaped characters .
        DECODE_PROC = Proc.new do |match|
            case match[1]
            when ?n
                "\n"
            when ?r
                "\r"
            when ?t
                "\t"
            when ?b
                "\b"
            when ?f
                "\f"
            when ?\\, 34, 47
                match[1].chr
            else
                match[1..-1].hex.chr
            end
        end

        DEFAULT_BUILDER = ObjectBuilder.new

        def initialize builder = nil
            @builder = builder || DEFAULT_BUILDER
        end

        def read input
            scanner = StringScanner.new input
            scanner.scan(/\s*\{\s*/) or fail scanner, "Expected opening curly bracket ({ at start of object)"
            object = @builder.create_root
            scan_object object, scanner
            scanner.skip(/\s*/)
            scanner.eos? or fail scanner, "Found unexpected data beyond end of JSON object"
            object
        end

    private

        def scan_object object, scanner
            unless scanner.scan(/\}\s*/) # empty object
                begin
                    name = scan_quoted scanner
                    scanner.scan(/\s*\:\s*/) or fail scanner, "Missing name/value separator (:)"
                    value = scan_value object, name, scanner
                    @builder.set_value object, name, value
                end while scanner.scan(/\s*,\s*/)
                scanner.scan(/\s*\}\s*/) or fail scanner, "Expected closing curly brackets at end of object (})"
            end
        end

        def scan_quoted scanner
            scanner.skip(/\"/) or fail scanner, "Expected opening quote (\" at start of name/value)"
            scanned = scanner.scan(/[^\"]*/)
            while scanned[-1] == ?\\
                scanned << '"'
                scanner.skip(/\"/)
                scanned << scanner.scan(/[^\"]*/)
            end
            scanner.skip(/\"/) or fail scanner, "Expected closing quote (\" at end of name/value)"
            scanned.gsub DECODE_REGEXP, &DECODE_PROC
        end

        def scan_value parent, name, scanner
            if scanner.match?(/"/)
                # Expecting quoted value
                scan_quoted scanner
            elsif scanner.scan(/\{\s*/)
                # Expecting object.
                object = @builder.create_object parent, name
                scan_object object, scanner
                object
            elsif scanner.scan(/\[\s*/)
                array = @builder.create_array parent, name
                unless scanner.scan(/\]\s*/) # empty array
                    # Expecting array
                    begin
                        value = scan_value object, name, scanner
                        array << value
                    end while scanner.scan(/\s*,\s*/)
                    scanner.scan(/s*\]\s*/) or fail scanner, "Expected closing brackets at end of array (])"
                end
                array
            elsif scanner.scan(/-?[[:digit:]]+(\.[[:digit:]]+)?([eE][\-+]?[[:digit:]]+)?/)
                value = scanner[0]
                if value =~ /[\.eE]/
                    value.to_f
                else
                    value.to_i
                end
            elsif scanner.scan(/true/)
                true
            elsif scanner.scan(/false/)
                false
            elsif scanner.scan(/null/)
                nil
            else
                fail scanner, "Expected a JSON value"
            end
        end

        def fail scanner, message
            pos = scanner.pos
            start = pos - 32
            start = 0 if start < 0
            scanner.pos = start
            message = message << "\n" << scanner.peek(64) << "\n"
            (pos - start).times { message << " " }
            message << "^"
            raise ParseError, message
        end

    end

end

