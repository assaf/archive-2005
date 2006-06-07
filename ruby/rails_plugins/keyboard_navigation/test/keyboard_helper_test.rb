require File.dirname(__FILE__) + "/../../../../test/test_helper"
require File.dirname(__FILE__) + "/../init"

# Re-raise errors caught by the controller.
class TestController < ActionController::Base ; def rescue_action(e) raise e end; end

class KeyboardHelperTest < Test::Unit::TestCase

    include KeyboardHelper

    def setup
        @controller = TestController.new
        @request    = ActionController::TestRequest.new
        @response   = ActionController::TestResponse.new
    end
    
    
    def test_shortcut
        update_page do |page|
            page.shortcut "x", "alert(event)"
        end
        assert_equal %Q{Keyboard.shortcuts.bindings["x"]=function(event){\nalert(event)\n};},
            @response.body
        update_page do |page|
            page.shortcut "x" do
                page.alert("x")
            end
        end
        assert_equal %Q{Keyboard.shortcuts.bindings["x"]=function(event){\nalert("x");\n};},
            @response.body
    end
    
    
    def test_navigator_and_options
        assert_equal %Q{<script type="text/javascript">\n//<![CDATA[\nif (!Keyboard.navigator) Keyboard.navigator = new Keyboard.Navigator({event:window.event, hash:{foo:bar}, nothing:null, returnTrue:function(){return true}, string:"xyz"});\n//]]>\n</script>},
            render(%Q{navigator :nothing=>nil, :string=>"xyz",
                :return_true=>Proc.new { "return true" },
                :event=>"window.event".to_sym,
                :hash=>{:foo=>:bar}
            })
    end


    def test_navigate_to_helper
        execute { navigate_to("element", :scroll=>true) }
        assert_equal ["element"], @response.cookies["navigator"]
        execute { navigate_to() }
        assert_equal [], @response.cookies["navigator"]
        execute { navigate_to(:next) }
        assert_equal [], @response.cookies["navigator"]
    end


    def test_navigate_to_rjs
        assert_equal %Q{Keyboard.navigator.navigateTo("element",{scroll:true});},
            update_page { |page| page.navigate_to("element", :scroll=>true) }
        assert_equal nil, @response.cookies["navigator"]
        assert_equal %Q{Keyboard.navigator.navigateTo(null,null);},
            update_page { |page| page.navigate_to() }
        assert_equal %Q{Keyboard.navigator.navigateTo(Keyboard.Navigator.next,null);},
            update_page { |page| page.navigate_to(:next) }
        assert_equal %Q{Keyboard.navigator.navigateTo(Keyboard.Navigator.previous,null);},
            update_page { |page| page.navigate_to(:previous) }
        assert_equal %Q{Keyboard.navigator.navigateTo(Keyboard.Navigator.remove,null);},
            update_page { |page| page.navigate_to(:remove) }
    end



    def update_page(&block)
        @controller.class.send :define_method, :index do
            render :update do |page|
                block.call(page)
            end
        end
        get :index
        return @response.body
    end
    

    def render(code)
        @controller.class.send :define_method, :index do
            render :inline=>"<%= #{code} %>"
        end
        get :index
        return @response.body
    end
    
    
    def execute(&block)
        @controller.class.send :define_method, :index do
            instance_eval &block
            render :text=>""
        end
        get :index
    end
    
end