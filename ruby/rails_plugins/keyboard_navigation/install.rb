require File.dirname(__FILE__) + '/../../../config/boot'

JAVASCRIPTS = ["keyboard.js"]
target = File.expand_path("public/javascripts", RAILS_ROOT)
JAVASCRIPTS.each do |script|
  if File.exist?(File.join(target, script))
    puts "#{script} already exists in #{target}"
  else
    puts "Adding #{script} to #{target}"
    source = File.open(File.join(File.dirname(__FILE__), "javascripts", script)) do |file|
      file.read
    end
    File.open(File.join(target, script), "w") do |file|
      file.write(source)
    end
  end
end
