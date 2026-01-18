require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Diabo' }

file_to_remove = 'WelcomeView.swift'

# Find the file reference
file_ref = project.files.find { |f| f.path == file_to_remove }

if file_ref
  # Remove from target
  target.source_build_phase.remove_file_reference(file_ref)
  
  # Remove from group (and project)
  file_ref.remove_from_project
  
  project.save
  puts "Removed #{file_to_remove} from project."
else
  puts "#{file_to_remove} not found in project."
end
