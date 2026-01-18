require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Recreate schemes
project.recreate_user_schemes

# Find the Diabo scheme and make it shared
# recreating user schemes puts them in xcuserdata
# we want to move it to xcshareddata

target_name = 'Diabo'
target = project.targets.find { |t| t.name == target_name }

if target
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  
  # Set the launch action to use the executable
  # This is often needed for the Run button to work
  
  shared_schemes_path = Xcodeproj::XCScheme.shared_data_path(project_path)
  Dir.mkdir(shared_schemes_path) unless Dir.exist?(shared_schemes_path)
  
  scheme_path = File.join(shared_schemes_path, "#{target_name}.xcscheme")
  scheme.save_as(project_path, target_name, true)
  
  puts "Shared scheme '#{target_name}' created successfully."
else
  puts "Target '#{target_name}' not found."
end
