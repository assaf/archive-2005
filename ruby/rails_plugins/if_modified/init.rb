require File.join(File.dirname(__FILE__), 'lib/if_modified') 
require File.join(File.dirname(__FILE__), 'lib/etag') 

ActionController::Base.class_eval do
  include ActionController::IfModified
end
ActiveRecord::Base.class_eval do
  include ActiveRecord::ETag
end
