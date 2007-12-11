require File.join(File.dirname(__FILE__), 'lib/if_modified') 

ActionController::Base.class_eval do
  include ActionController::IfModified
end
