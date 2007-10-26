# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.


require 'be_ok'

require 'if_modified'
ActionController::Base.send :include, IfModified::ActionControllerMethods
ActiveRecord::Base.send :include, IfModified::ActiveRecordMethods

require 'presenter'
require 'see_other'
