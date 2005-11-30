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
        puts "Benchmark using the object"
        puts JSON::dump(object, nil, 4)
        puts
        count = 1000

        puts "Serialized text size"
        json = JSON::dump(object)
        puts "JSON: #{json.length}"
        json_in = JSON::dump(object, nil, 4)
        puts "JSON*: #{json_in.length}"
        yaml = YAML::dump(object)
        puts "YAML: #{yaml.length}"
        marshal = Marshal::dump(object)
        puts "Marshal: #{marshal.length}"
        xml = REXML::dump(object)
        puts "REXML: #{xml.length}"
        xml = REXML::dump(object, 4)
        puts "REXML*: #{xml.length}"
        puts
        puts "* Indented output"

        test = Proc.new do |dump, load|
            Benchmark.bmbm(20) do |bm|
                bm.report("JSON:") do
                    count.times { JSON::dump(object) } if dump
                    count.times { JSON::load(json) } if load
                end
                bm.report("JSON*:") do
                    count.times { JSON::dump(object, nil, 4) } if dump
                    count.times { JSON::load(json_in) } if load
                end
                bm.report("YAML:") do
                    count.times { YAML::dump(object, StringIO.new) } if dump
                    count.times { YAML::load(yaml) } if load
                end
                bm.report("Marshal:") do
                    count.times { Marshal::dump(object) } if dump
                    count.times { Marshal::load(marshal) } if load
                end
                if dump && !load
                    bm.report("REXML:") do
                        count.times { REXML::dump(object) }
                    end
                    bm.report("REXML*:") do
                        count.times { REXML::dump(object, 4) }
                    end
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

end

if __FILE__ == $0
    JSON::benchmark
end