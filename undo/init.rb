ActionView::Base.send :include, UndoHelper
ActionController::Base.send :include, UndoHelper
