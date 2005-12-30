require 'strscan'

module JSON

    class ParseError < RuntimeError
    end


    class Parser

        # Regular expression for catching all the characters that must be decoded.
        DECODE_REGEXP = /\\[nrftb\\\/"]|\\\d{4}/ #:nodoc:

        # Proc for decoding escaped characters .
        DECODE_PROC = Proc.new do |match| #:nocod:
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

        REGEXP_OPENING_CURLY = /^\s*\{/ #:nodoc:
        REGEXP_WS = /^\s*/ #:nodoc:
        REGEXP_FIRST_NON_WS = /^\s*[^\s]/ #:nodoc:
        REGEXP_COLON = /^\s*\:/ #:nodoc:
        REGEXP_NON_QUOTE = /^[^\"]*/ #:nodoc:
        REGEXP_NUMBER = /^(-?[[:digit:]]+(\.[[:digit:]]+)?([eE][\-+]?[[:digit:]]+)?)[^[:digit:]]/ #:nodoc:
        REGEXP_IS_FLOAT = /[\.eE]/ #:nodoc:


        def initialize(input)
            case input
            when String
                @scanner = ScanFromString.new input
            when IO
                @scanner = ScanFromIO.new input
            end
        end

        def read
            @scanner.expect(REGEXP_OPENING_CURLY, "Expected opening curly bracket ({}) at start of object")
            object = create_root
            scan_object object
            @scanner.skip(REGEXP_WS)
            # What do we do about this??
            #scanner.eos? or fail scanner, "Found unexpected data beyond end of JSON object"
            object
        end

    protected

        def create_root
            {}
        end

        def create_object(parent, name)
            {}
        end

        def create_array(parent, name)
            []
        end

        def set_value(parent, name, value)
            parent[name] = value
        end


    private

        def scan_object(object)
            scanned = @scanner.scan(REGEXP_FIRST_NON_WS)
            return if scanned[-1] == ?} # empty object
            name, value = nil, nil
            # TODO: need to support non-quoted names!
            while scanned[-1] == 34 # double quote
                name = scan_quoted
                @scanner.expect(REGEXP_COLON, "Expected colon (:) separating property name from its value")
                value = scan_value object, name
                set_value object, name, value
                scanned = @scanner.scan(REGEXP_FIRST_NON_WS)
                return if scanned[-1] == ?} # end of object
                @scanner.fail "Expected comma (,) separating properties, or curly bracket (}) at end of object" unless scanned[-1] == ?,
                scanned = @scanner.scan(REGEXP_FIRST_NON_WS)
            end
            @scanner.fail "Expected quote (\") at beginning of property name"
        end


        def scan_quoted
            scanned = @scanner.scan(REGEXP_NON_QUOTE)
            while scanned[-1] == ?\\
                scanned << '"'
                raise "Scanner error" unless @scanner.getch == '"'
                scanned << @scanner.scan(REGEXP_NON_QUOTE)
            end
            @scanner.fail "Expected quote (\") at end of property name/value" unless @scanner.getch == '"'
            scanned.gsub DECODE_REGEXP, &DECODE_PROC
        end

        def scan_value(parent, name)
            scanned = @scanner.scan(REGEXP_FIRST_NON_WS)[-1]
            if scanned == 34
                # Expecting quoted value
                scan_quoted
            elsif scanned == ?{
                # Expecting object.
                object = create_object parent, name
                scan_object object
                object
            elsif scanned == ?[
                array = create_array parent, name
                scanned = @scanner.scan(REGEXP_FIRST_NON_WS)[-1]
                unless scanned == ?] # empty array
                    while true
                        @scanner.pushback(scanned)
                        array << scan_value(object, name)
                        scanned = @scanner.scan(REGEXP_FIRST_NON_WS)[-1]
                        break if scanned == ?] # end of array
                        @scanner.fail "Expected comma (,) separating array values, or bracket (]) at end of array" unless scanned == ?,
                        scanned = @scanner.scan(REGEXP_FIRST_NON_WS)[-1]
                    end
                end
                array
            elsif scanned == ?t && @scanner.scan(/^rue/)
                true
            elsif scanned == ?f && @scanner.scan(/^alse/)
                false
            elsif scanned == ?n && @scanner.scan(/^ull/)
                nil
            elsif (scanned >= ?0 && scanned <= ?9) || scanned == ?-
                @scanner.pushback scanned
                scanned = @scanner.scan(REGEXP_NUMBER)
                @scanner.pushback scanned[-1]
                value = scanned[0..-2]
                if value =~ REGEXP_IS_FLOAT
                    value.to_f
                else
                    value.to_i
                end
            else
                @scanner.fail "Expected a valid JSON value: quoted string, number, true, false or null"
            end
        end

    end


    class ScanFromString < StringScanner

        def initialize(string)
            super
        end

        def expect(regexp, message)
            scanned = scan regexp
            fail message unless scanned
            scanned
        end

        def eos?
            # what do we do here?
        end

        def pushback(ch)
            self.pos = pos - 1
        end

        def fail(message)
            current = pos
            start = current - 32
            start = 0 if start < 0
            last_nl = string.rindex "\n", current
            start = last_nl + 1 if last_nl >= start
            self.pos = start
            message << "\n#{peek(64)}\n"
            (current - start).times { message << " " }
            message << "^"

            error = ParseError.exception(message)
            error.set_backtrace caller
            raise error
        end

    end


    class ScanFromIO

        def initialize(io)
            @io = io
            @string = io.read
            @scanner = StringScanner @string
        end

        def expect(regexp, message)
            scanned = scan regexp
            fail message unless scanned
            scanned
        end

        def scan(regexp)
            scanned = @scanner.scan regexp
            while !scanned
                fail "Reached end of stream" if io.eof?
                @string << @io.read
                scanned = @scanner.scan regexp
            end
            scanned
        end

        def getch
            ch = @scanner.getch
            while !ch
                fail "Reached end of stream" if io.eof?
                @string << @io.read
                ch = @scanner.getch
            end
            ch
        end

        def skip(regexp)
            count = @scanner.skip regexp
            while !count
                fail "Reached end of stream" if io.eof?
                @string << @io.read
                count = @scanner.skip regexp
            end
            count
        end

        def eos?
            # what do we do here?
        end

        def pushback(ch)
            self.pos = pos - 1
        end

        def fail(message)
            current = @scanner.pos
            start = current - 32
            start = 0 if start < 0
            last_nl = @string.rindex "\n", current
            start = last_nl + 1 if last_nl >= start
            @scanner.pos = start
            message << "\n#{@scanner.peek(64)}\n"
            (current - start).times { message << " " }
            message << "^"

            error = ParseError.exception(message)
            error.set_backtrace caller
            raise error
        end

    end

end

