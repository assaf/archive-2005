require 'stringio'
require 'strscan'

module JSON

    def self.dump object, output = nil, indent = 0
        ser = Serializer::new output, indent
        ser.write object
        if output
            ser.flush
            output
        else
            ser.to_str
        end
    end


    def self.load input
        #input = StringIO.new(input) unless input.is_a?(IO)
        parser = Parser::new
        parser.read input
    end


    class Serializer

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

        DEFAULT_INDENT = 4

        def initialize output = nil, indent = 0, &block
            @separator = false
            @io = output || StringIO.new
            @closed = false
            if indent > 0
                @indent, @indent_by = 1, " " * indent
            else
                @indent, @indent_by = 0, nil
            end
            @io << '{'
            instance_eval &block if block
        end


        def self.indented output = nil, &block
            self.new output, indent = DEFAULT_INDENT, &block
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
            when Hash
                raise ArgumentError, "only one hash allowed, no block expected" if args.length > 1 || block
                name, value = nil, nil
                args[0].each_pair do |name, value|
                    @io << ',' if @separator
                    if @indent_by
                        @io << "\n"
                        @indent.times { @io << @indent_by }
                    end
                    name = name.to_s unless name.instance_of?(String)
                    @io << '"' << name.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '": '
                    write_value value
                end
            when String, Symbol, Numeric
                raise ArgumentError, "expected second argument with value, or a block" unless args.length == 2 || block
                @io << ',' if @separator
                if @indent_by
                    @io << "\n"
                    @indent.times { @io << @indent_by }
                end
                name = name.instance_of?(String) ? args[0] : args[0].to_s
                @io << '"' << name.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '": '
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
            ser = Serializer.new nil, @indent_by
            ser.instance_variable_set :@indent,  @indent + 1
            ser.instance_eval &block
            ser
        end

    private

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
                    @io << '"' << value.to_s.gsub(ENCODE_REGEXP, &ENCODE_PROC) << '"'
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


    class Parser

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
            when ?\\, 34 # TODO: slash
                match[1]
            else
                # TODO: convert four hexadigits to code
            end
        end

        def initialize
        end

        def read input
            scanner = StringScanner.new input
            scanner.scan(/\s*\{\s*/) or fail "Expected opening curly bracket ({ at start of object)"
            object = scan_object scanner
            scanner.skip(/\s*/)
            scanner.eos? or fail "Found unexpected data beyond end of JSON object"
            object
        end

    private

        def scan_object scanner
            object = {}
            begin
                name = scan_quoted scanner
                scanner.scan(/\s*\:\s*/) or fail "Missing name/value separator (:)"
                object[name] = scan_value scanner
            end while scanner.scan(/\s*,\s*/)
            scanner.scan(/\s*\}\s*/) or fail "Expected closing curly brackets at end of object (})"
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
            scanned.gsub DECODE_REGEXP, &DECODE_PROC
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





def test_write_methods
    puts "test_write_methods"
    puts JSON::Serializer.indented {
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
    }.to_str
end


def test_hash_write
    puts "test_hash_write"
    json = JSON::Serializer.indented
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



def test_base_types
    puts "test_base_types"
    puts JSON::Serializer.indented {
        write "false", false
        write "true", true
        write "null", nil
        write "float", 12.34
        write "integer", 56
        write "array", ["foo", :bar, 56, Time.new, nil]
    }.to_str
end



def bechmark

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

    puts "Serialized text size"
    json = JSON::dump(object)
    puts "JSON: #{json.length}"
    json_in = JSON::dump(object, nil, 4)
    puts "JSON (indent): #{json_in.length}"
    yaml = YAML::dump(object)
    puts "YAML: #{yaml.length}"
    marshal = Marshal::dump(object)
    puts "Marshal: #{marshal.length}"

    test = Proc.new do |dump, load|
        Benchmark.bmbm(20) do |bm|
            bm.report("JSON:") do
                count.times { JSON::dump(object) } if dump
                count.times { JSON::load(json) } if load
            end
            bm.report("JSON (indent):") do
                count.times { JSON::dump(object, nil, 4) } if dump
                count.times { JSON::load(json_in) } if load
            end
            bm.report("YAML:") do
                count.times { YAML::dump(object) } if dump
                count.times { YAML::load(yaml) } if load
            end
            bm.report("Marshal:") do
                count.times { Marshal::dump(object) } if dump
                count.times { Marshal::load(marshal) } if load
            end
        end
    end
    puts
    puts "Serialization (dump):"
    test.call true, false
    puts
    puts "Parsing (load):"
    test.call false, true
    puts
    puts "Round-trip (dump, load):"
    test.call true, true

end


def test_roundtrip
    object = {
        "glossary"=>{
            "title"=>"example \n glossary",
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
    string = JSON::dump(object).to_s
    object2 = JSON::load string
    puts "Round trip completed: #{object2 == object}"
    puts JSON::dump(object2, nil, 4)
end

#test_write_methods
#test_hash_write
#test_base_types
test_roundtrip
bechmark
