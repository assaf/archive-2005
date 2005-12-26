require 'lib/json'
require 'benchmark'
require 'yaml'
require 'stringio'
require "rexml/document"

module REXML

    def self.rexml_add_value parent, name, value
        case value
        when String, Numeric, Float, Symbol, TrueClass, FalseClass, NilClass
            element = REXML::Element.new name
            element.add_text value.to_s
            parent.add_element element
        when Array
            value.each do |item|
                rexml_add_value parent, name, item
            end
        when Hash
            element = REXML::Element.new name
            value.each_pair do |name, value|
                rexml_add_value element, name, value
            end
            parent.add_element element
        end
    end

    def self.dump object, indent = 0
        root = REXML::Document.new
        object.each_pair do |name, value|
            rexml_add_value root, name, value
        end
        output = String.new
        root.write(output, indent)
        output
    end

end


module JSON

    class BenchTest

        def initialize name, &block
            @name = name
            @load = nil
            instance_eval &block
        end

        def dump &block
            @dump = block
        end

        def load &block
            @load = block
        end

        def run count, object, gc = true
            puts "#{@name}:"
            text = @dump.call object
            puts "Serialized size: #{text.length} bytes"
            Benchmark.bmbm(10) do |bm|
                bm.report("#{@name}: Serialize:") do
                    GC.disable unless gc
                    count.times { @dump.call object }
                    GC.enable unless gc
                end
                if @load
                    bm.report("#{@name}: Parse:") do
                        GC.disable unless gc
                        count.times { @load.call text }
                        GC.enable unless gc
                    end
                    bm.report("#{@name}: Round-trip:") do
                        GC.disable unless gc
                        count.times { text = @dump.call object ; @load.call text }
                        GC.enable unless gc
                    end
                end
            end
            puts ; puts
        end

    end

    def self.benchmark

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
        puts "Ruby #{RUBY_VERSION} / #{RUBY_PLATFORM}"
        puts "Benchmark using the object"
        puts JSON::dump(object, nil, 4)
        puts
        count = 1000


        tests = []
        tests << BenchTest.new("JSON") do
            dump { |object| JSON::dump(object) }
            load { |text| JSON::load(text) }
        end
        tests << BenchTest.new("JSON*") do
            dump { |object| JSON::dump(object, nil, 4) }
            load { |text| JSON::load(text) }
        end
        tests << BenchTest.new("YAML") do
            dump { |object| YAML::dump(object) }
            load { |text| YAML::load(text) }
        end
        tests << BenchTest.new("Marshal") do
            dump { |object| Marshal::dump(object) }
            load { |text| Marshal::load(text) }
        end
        tests << BenchTest.new("REXML") do
            dump { |object| REXML::dump(object) }
        end
        tests << BenchTest.new("REXML*") do
            dump { |object| REXML::dump(object, 4) }
        end

        tests.each do |test|
            test.run count, object, true
        end
        puts
        puts "* Indented output"

    end

end

if __FILE__ == $0
    JSON::benchmark
end