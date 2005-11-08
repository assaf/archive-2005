$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module ReliableMsg

    PACKAGE = "reliable-msg"
    VERSION = '1.0.0'

end

require 'reliable-msg/queue'
require 'reliable-msg/cli'
