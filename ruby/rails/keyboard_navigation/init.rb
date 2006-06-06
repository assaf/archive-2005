ActionView::Helpers::AssetTagHelper.send :register_javascript_include_default, "keyboard"
ActionView::Base.send :include, KeyboardHelper
ActionController::Base.send :include, KeyboardHelper
