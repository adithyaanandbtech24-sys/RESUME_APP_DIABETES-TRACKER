require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Diabo' }

unless target
  puts "Target 'Diabo' not found."
  exit 1
end

# Files to add
files_to_add = [
  'Diabo/ProfessionalWelcomeView.swift',
  'Diabo/WelcomeAnimationView.swift',
  'Diabo/WelcomeView.swift'
]

# Find the Diabo group (where the files are physically located)
diabo_group = project.main_group.find_subpath('Diabo', false)

unless diabo_group
  puts "Group 'Diabo' not found in project structure."
  exit 1
end

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if file already in group
  existing_ref = diabo_group.files.find { |f| f.path == file_name }
  
  unless existing_ref
    file_ref = diabo_group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name} to project and target."
  else
    # Ensure it's in the target anyway
    unless target.source_build_phase.files.find { |f| f.file_ref == existing_ref }
      target.add_file_references([existing_ref])
      puts "Linked existing #{file_name} to target."
    else
      puts "#{file_name} already in project and target."
    end
  end
end

project.save
puts "Project updated successfully."
