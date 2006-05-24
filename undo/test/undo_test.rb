require "test/unit"
require File.dirname(__FILE__) + "/../lib/undo_helper"


class UndoTest < Test::Unit::TestCase

    include UndoHelper

    def test_undo_method
        assert_kind_of Undo, undo
    end


    def test_push_new_action
        assert_equal "", undo.render
        undo.push "Undo title", {:controller=>"foo", :action=>"bar"}
        assert_equal %Q{<form action="foo/bar"><input value="Undo" title="Undo title"></form>},
            undo.render
        undo.pop
        assert_equal "", undo.render
    end


    def test_set_button_and_class
        undo.push "Undo title", {:controller=>"foo", :action=>"bar"}
        assert_equal %Q{<form action="foo/bar" class="fc"><input value="Button" class="sc" title="Undo title"></form>},
            undo.render("Button", :form=>{:class=>"fc"}, :button=>{:class=>"sc"})
    end


    def test_disabled_button
        assert_equal "", undo.render
        assert_equal %Q{<form action="/" class="fc"><input value="Button" disabled="true" class="sc"></form>},
            undo.render("Button", :form=>{:class=>"fc"}, :disabled=>{:class=>"sc"})
    end


    def test_multilevel_undo
        Undo.levels = 2
        assert_equal 2, Undo.levels
        assert_equal "", undo.render
        undo.push "Undo title", {:controller=>"foo", :action=>"bar1"}
        assert_equal %Q{<form action="foo/bar1"><input value="Undo" title="Undo title"></form>}, undo.render
        undo.push "Undo title", {:controller=>"foo", :action=>"bar2"}
        assert_equal %Q{<form action="foo/bar2"><input value="Undo" title="Undo title"></form>}, undo.render
        undo.pop
        assert_equal %Q{<form action="foo/bar1"><input value="Undo" title="Undo title"></form>}, undo.render
        undo.pop
        assert_equal "", undo.render
    end



    def session
        @session ||= {}
    end

    def form_remote_tag(options)
        url = options[:url] || {}
        html = options[:html].map {|k,v| " #{k}=\"#{v}\"" } if options[:html]
        %Q{<form action="#{url[:controller]}/#{url[:action]}"#{html}>}
    end

    def submit_tag(name, options)
        html = options.map {|k,v| " #{k}=\"#{v}\"" } if options
        %Q{<input value="#{name}"#{html}>}
    end

    def end_form_tag()
        "</form>"
    end

end
