require 'stringio'
require 'strscan'

module JSON

    class Writer

        # Regular expression for catching all the characters that must be encoded.
        ENCODE_REGEXP = /[^[:print:]]|["\\]/

        # Proc for encoding non-printable characters, quote and back-slash.
        ENCODE_PROC = Proc.new do |match|
            case match[0]
            when 34
                '\\"'
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

        def self.indented &block
            self.new indent = 4, &block
        end

        def initialize indent = 0, &block
            @separator = false
            @io = StringIO.new
            @indent_at = @indent_by = indent > 0 ? indent : 0
            @io << '{'
            instance_eval &block if block
        end

        def to_str
            # Make sure to close object exactly once for each call to this method.
            unless @io.closed_write?
                # Closing indentation, since this may be nested in another object.
                if @indent_by > 0
                    @indent_at -= @indent_by
                    @io << "\n"
                    @indent_at.times { @io << ' ' }
                end
                @io << '}'
                @io.close_write
            end
            @io.string
        end

        alias :to_s :to_str

        def write *args, &block
            raise ArgumentError, "wrong number of arguments (0 for 1)" unless args.length > 0
            case args[0]
            when Hash
                raise ArgumentError, "only one hash allowed, no block expected" if args.length > 1 || block
                name, value = nil, nil
                args[0].each_pair do |name, value|
                    @io << ',' if @separator
                    if @indent_by > 0
                        @io << "\n"
                        @indent_at.times { @io << ' ' }
                    end
                    name = name.to_s unless name.instance_of?(String)
                    @io << '"' << name.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '": '
                    write_value value
                end
            when String, Symbol, Numeric
                raise ArgumentError, "expected second argument with value, or a block" unless args.length == 2 || block
                @io << ',' if @separator
                if @indent_by > 0
                    @io << "\n"
                    @indent_at.times { @io << ' ' }
                end
                name = name.instance_of?(String) ? args[0] : args[0].to_s
                @io << '"' << name.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '": '
                if block
                    separator, @separator = @separator, false
                    @io << '{'
                    if @indent_by > 0
                        @indent_at += @indent_by
                        instance_eval &block
                        @indent_at -= @indent_by
                        @io << "\n"
                        @indent_at.times { @io << ' ' }
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
            writer = Writer.new @indent_by
            writer.indent_at = @indent_at + @indent_by
            writer.do &block
            writer
        end

        def self.write *args, &block
            self.new.write(*args, &block).to_s
        end

    private

        def indent_at= count
            @indent_at = count
        end

        def do &block
            instance_eval &block
        end

        def write_value value
            case value
            when String
                @io << '"' << value.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '"'
            when Numeric
                @io << value.to_s
            when TrueClass
                @io << "true"
            when FalseClass
                @io << "false"
            when NilClass
                @io << "null"
            when Time
                @io << "\"" << value.xmlschema << "\""
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
                if @indent_by > 0
                    @indent_at += @indent_by
                    value.each_pair { |name, value| write name, value }
                    @indent_at -= @indent_by
                    @io << "\n"
                    @indent_at.times { @io << ' ' }
                else
                    value.each_pair { |name, value| write name, value }
                end
                @io << '}'
                @separator = true
            when Writer
                @io << value.to_str
            else
                if value.respond_to?(:to_json)
                    @io << value.to_json
                else
                    @io << '"' << value.to_s.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '"'
                end
            end
        end

    end


    class Reader

        def initialize
        end

        def read string
            scanner = StringScanner.new string
            scanner.scan(/\s*\{\s*/) or fail "Expected opening curly bracket ({ at start of object)"
            object = scan_object scanner
            scanner.skip(/\s*/)
            scanner.eos? or fail "Found unexpected data beyond end of JSON object"
            object
        end

        def self.read string
            Reader.new.read string
        end

    private

        def scan_object scanner
            object = {}
            begin
                name = scan_quoted scanner
                scanner.scan(/\s*\:\s*/) or fail "Missing name/value separator (:)"
                object[name] = scan_value scanner
            end while scanner.scan(/\s*,\s*/)
            scanner.scan(/s*\}\s*/) or fail "Expected closing curly brackets at end of object (})"
            object
        end

        def scan_quoted scanner
            scanner.skip(/\"/) or fail "Expected opening quote (\" at start of name/value)"
            scanned = scanner.scan(/[^\"]*/)
            while scanned[-1] == ?\\
                scanned << '"'
                scanner.skip(/\"/)
                scanned << scanner.scan(/[^\"]*/)
            end
            scanner.skip(/\"/) or fail "Expected closing quote (\" at end of name/value)"
            scanned
        end

        def scan_value scanner
            if scanner.match?(/"/)
                # Expecting quoted value
                scan_quoted scanner
            elsif scanner.scan(/\{\s*/)
                # Expecting object.
                scan_object scanner
            elsif scanner.scan(/\[\s*/)
                # Expecting array
                array = []
                begin
                    array << scan_value(scanner)
                end while scanner.scan(/\s*,\s*/)
                scanner.scan(/s*\]\s*/) or fail "Expected closing brackets at end of array (])"
                array
            # TODO: add numbers
            elsif scanner.scan(/true/)
                true
            elsif scanner.scan(/false/)
                false
            elsif scanner.scan(/null/)
                nil
            else
                fail "Expected a JSON value"
            end
        end

    end

end





def test_1
    puts JSON::Writer.indented {
        write "glossary", object {
            write "title", "example glossary"
            write "GlossDiv", object {
                write "title", "S"
                write "GlossList", [
                    object {
                        write "ID", "SGML"
                        write "SortAs", "SGML"
                        write "GlossTerm", "Standard Generalized Markup Language"
                        write "Acronym", "SGML"
                        write "Abbrev", "ISO 8879:1986"
                        write "GlossDef", "A meta-markup language, used to create markup languages such as DocBook."
                        write "GlossSeeAlso", ["GML", "XML", "markup"]
                    }
                ]
            }
        }
    }
end


def test_2
    json = JSON::Writer.indented
    json.write "glossary"=>{
        "title"=>"example glossary",
        "GlossDiv"=>{
            "title"=>"S",
            "GlossList"=>[{
                "ID"=>"SGML",
                "SortAs"=>"SGML",
                "GlossTerm"=>"Standard Generalized Markup Language",
                "Acronym"=>"SGML",
                "Abbrev"=>"ISO 8879:1986",
                "GlossDef"=>"A meta-markup language, used to create markup languages such as DocBook.",
                "GlossSeeAlso"=>["GML", "XML", "markup"]
            }]
        }
    }
    puts json.to_str
end


def test_3
    puts JSON::Writer.new {
        write "false", false
        write "true", true
        write "null", nil
        write "float", 12.34
        write "integer", 56
        write "array", ["foo", :bar, 56, Time.new, nil]
    }
end


def write_test

    require 'benchmark'
    require 'yaml'

    object = {
        "glossary"=>{
            "title"=>"example glossary",
            "GlossDiv"=>{
                "title"=>"S",
                "GlossList"=>[{
                    "ID"=>"SGML",
                    "SortAs"=>"SGML",
                    "GlossTerm"=>"Standard Generalized Markup Language",
                    "Acronym"=>"SGML",
                    "Abbrev"=>"ISO 8879:1986",
                    "GlossDef"=>"A meta-markup language, used to create markup languages such as DocBook.",
                    "GlossSeeAlso"=>["GML", "XML", "markup"]
                }]
            }
        }
    }
    count = 1000

    puts "JSon (indented) size: #{JSON::Writer.indented.write(object).to_s.length}"

    puts "JSon size: #{JSON::Writer::write(object).to_s.length}"
    puts Benchmark.measure {
        count.times do
            JSON::Writer::write(object).to_s
        end
    }

    puts "YAML size: #{YAML::dump(object).length}"
    puts Benchmark.measure {
        count.times do
            YAML::dump(object)
        end
    }

    puts "Marshal size: #{Marshal.dump(object).length}"
    puts Benchmark.measure {
        count.times do
            Marshal::dump(object)
        end
    }

end


object = {
    "glossary"=>{
        "title"=>"example glossary",
        "GlossDiv"=>{
            "title"=>"S",
            "GlossList"=>[{
                "ID"=>"SGML",
                "SortAs"=>"SGML",
                "GlossTerm"=>"Standard Generalized Markup Language",
                "Acronym"=>"SGML",
                "Abbrev"=>"ISO 8879:1986",
                "GlossDef"=>"A meta-markup language, used to create markup languages such as DocBook.",
                "GlossSeeAlso"=>["GML", "XML", "markup"]
            }]
        }
    }
}
string = JSON::Writer.write(object).to_s
reader = JSON::Reader.new
object2 = reader.read string
puts object2 == object
puts JSON::Writer.indented.write(object2)


require 'benchmark'
count = 1000
puts Benchmark.measure {
    count.times do
        string = JSON::Writer::write(object).to_s
        object = JSON::Reader::read(string)
    end
}
puts Benchmark.measure {
    count.times do
        string = Marshal::dump(object)
        object = Marshal::load(string)
    end
}
