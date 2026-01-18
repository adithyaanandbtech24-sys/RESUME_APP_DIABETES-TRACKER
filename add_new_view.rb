require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'Diabo' }

# Find the main Diabo group
main_group = project.main_group['Diabo']
sub_group = main_group['Diabo']

files_to_add = ['AllInOneDashboardView.swift']

files_to_add.each do |file_name|
  file_path = "Diabo/#{file_name}"
  
  # Check if file reference already exists
  existing_ref = main_group.files.find { |f| f.path == file_name }
  
  if existing_ref.nil?
    # Add new file reference to sub-group
    new_ref = sub_group.new_file(file_name)
    target.source_build_phase.add_file_reference(new_ref)
    puts "Added #{file_name} to project and target."
  else
    puts "#{file_name} already exists in project."
  end
end

project.save
puts "Project saved."
