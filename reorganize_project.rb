require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'Diabo' }

# Find the main groups
main_group = project.main_group['Diabo']
sub_group = main_group['Diabo'] # the sub-group also named Diabo

files_to_move = [
  'ProfessionalWelcomeView.swift',
  'WelcomeAnimationView.swift'
]

files_to_move.each do |file_name|
  # Find current reference
  file_ref = main_group.files.find { |f| f.path == file_name }
  
  if file_ref
    # Remove from main group
    main_group.children.delete(file_ref)
    
    # Add to sub-group
    new_ref = sub_group.new_file(file_name)
    puts "Moved #{file_name} to sub-group"
    
    # Update build phase if necessary (new_file might have created a new ref)
    build_phase = target.source_build_phase
    # Find and remove old build file
    old_build_file = build_phase.files.find { |bf| bf.file_ref && bf.file_ref.path == file_name }
    if old_build_file
        build_phase.files.delete(old_build_file)
    end
    # Add new ref to build phase
    build_phase.add_file_reference(new_ref)
  else
    puts "#{file_name} not found in main group"
  end
end

project.save
puts "Project structural changes saved."
