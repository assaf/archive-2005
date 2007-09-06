# Create app/presenters.
dir = File.join(RAILS_ROOT, "app", "presenters")
unless File.exist?(dir)
  puts "Creating #{dir}"
  Dir.mkdir dir
end
