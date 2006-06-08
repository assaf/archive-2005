require File.dirname(__FILE__) + '/../../../config/boot'

JAVASCRIPTS = ["keyboard.js"]
target = File.expand_path("public/javascripts", RAILS_ROOT)
JAVASCRIPTS.each do |script|
    if File.exist?(File.join(target, script))
        puts "Removing #{File.join(target, script)}"
        File.delete File.join(target, script)
    end
end
