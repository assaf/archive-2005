# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.


require 'if_modified'
ActionController::Base.send :include, IfModified::ActionControllerMethods
ActiveRecord::Base.send :include, IfModified::ActiveRecordMethods


require 'presenter'
# That way we're able to use everything in app/presenters.
Dependencies.load_paths += %W( #{RAILS_ROOT}/app/presenters ) if defined?(RAILS_ROOT)
ActionController::Base.send :include, Presenter::PresentingMethods
