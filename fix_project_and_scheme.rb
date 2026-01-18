require 'xcodeproj'
require 'fileutils'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Diabo' }

unless target
  puts "Target 'Diabo' not found."
  exit 1
end

# 1. Ensure Products group exists and has the .app reference
products_group = project.main_group.find_subpath('Products', true)
product_ref = products_group.files.find { |f| f.path == 'Diabo.app' }

unless product_ref
  product_ref = products_group.new_reference('Diabo.app')
  product_ref.include_in_index = '0'
  product_ref.set_last_known_file_type('wrapper.application')
  puts "Created Diabo.app product reference."
end

# 2. Link product reference to target
target.product_reference = product_ref

# 3. Save project changes
project.save

# 4. Create shared scheme
# Using the Project#recreate_user_schemes logic but for a shared scheme
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)

# The shared data path for schemes
shared_schemes_path = File.join(project_path, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(shared_schemes_path)

scheme.save_as(project_path, 'Diabo', true)
puts "Shared scheme 'Diabo' created successfully in xcshareddata."
