$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'json/serializer'
require 'json/parser'

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


    def self.load input, builder = nil
        #input = StringIO.new(input) unless input.is_a?(IO)
        parser = Parser::new builder
        parser.read input
    end

end