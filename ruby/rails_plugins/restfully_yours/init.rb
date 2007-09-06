require 'if_modified'
ActionController::Base.send :include, IfModified::ActionControllerMethods
ActiveRecord::Base.send :include, IfModified::ActiveRecordMethods


require 'presenter'
# That way we're able to use everything in app/presenters.
Dependencies.load_paths += %W( #{RAILS_ROOT}/app/presenters )
ActionController::Base.send :include, Presenter::PresentingMethods
