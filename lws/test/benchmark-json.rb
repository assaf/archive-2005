require 'lib/json'
require 'benchmark'
require 'yaml'

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

end

if __FILE__ == $0
    JSON::benchmark
end