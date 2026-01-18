require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Diabo' }

files_to_add = [
  'Diabo/ProfessionalWelcomeView.swift',
  'Diabo/WelcomeAnimationView.swift'
]

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # Find or create file reference
  # First check if it's already there
  file_ref = project.files.find { |f| f.path == file_name }
  
  if !file_ref
    # Check if it's in the group
    group = project.main_group['Diabo']
    if group
        file_ref = group.new_file(file_name)
        puts "Created reference for #{file_name}"
    else
        puts "Error: Could not find Diabo group"
        next
    end
  end

  # Ensure it's in the target build phase
  build_phase = target.source_build_phase
  if !build_phase.files_references.include?(file_ref)
    build_phase.add_file_reference(file_ref)
    puts "Added #{file_name} to target build phase"
  else
    puts "#{file_name} already in target build phase"
  end
end

project.save
puts "Project saved successfully."
