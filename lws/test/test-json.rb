require 'test/unit'
require 'json'

class TestQueue < Test::Unit::TestCase


    def setup
        @object = {
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
    end

    def test_write_methods
        json = JSON::Serializer.indented {
            write "glossary"=>object {
                write "title"=>"example glossary"
                write "GlossDiv"=>object {
                    write "title"=>"S"
                    write "GlossList"=>[
                        object {
                            write "ID"=>"SGML"
                            write "SortAs"=>"SGML"
                            write "GlossTerm"=>"Standard Generalized Markup Language"
                            write "Acronym"=>"SGML"
                            write "Abbrev"=>"ISO 8879:1986"
                            write "GlossDef"=>"A meta-markup language, used to create markup languages such as DocBook."
                            write "GlossSeeAlso"=>["GML", "XML", "markup"]
                        }
                    ]
                }
            }
        }.to_str
        assert @object == JSON::load(json), "Round-trip failed when using write methods"
    end

    def test_write_hash
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
        json = json.to_str
        assert @object == JSON::load(json), "Round-trip failed when using write with hash"
    end

    def test_base_types
        object = {
            "false"=>false,
            "true"=>true,
            "null"=>nil,
            "float"=>12.34,
            "integer"=>56,
            "array"=>["foo", 56, nil],
            "empty_array"=>[],
            "empty_object"=>{}
        }
        json = JSON::dump(object)
        assert object == JSON::load(json), "Round-trip failed when testing base types"
    end

    def test_encoding
        object = {
            "encoded"=>"quote \" slash / backslash \\ new line \n carriage return \r form feed \f tab \t backspace \b other \x3"
        }
        encoded = "{\"encoded\": \"quote \\\" slash \\/ backslash \\\\ new line \\n carriage return \\r form feed \\f tab \\t backspace \\b other \\0003\"}"
        json = JSON::dump(object)
        assert json == encoded, "Encoding failed"
        assert object == JSON::load(json), "Round-trip failed when testing encoding"
    end

end