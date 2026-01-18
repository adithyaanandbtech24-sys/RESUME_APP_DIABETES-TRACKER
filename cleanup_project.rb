require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'Diabo' }

# Remove WelcomeView.swift from build phase (file doesn't exist)
build_phase = target.source_build_phase
files_to_remove = []
build_phase.files.each do |bf|
  if bf.file_ref && bf.file_ref.path == 'WelcomeView.swift'
    files_to_remove << bf
    puts "Found WelcomeView.swift in build phase, will remove."
  end
end

files_to_remove.each { |bf| build_phase.files.delete(bf) }

# Remove duplicates - keep track of seen files
seen_files = {}
duplicates_to_remove = []

build_phase.files.each do |bf|
  if bf.file_ref && bf.file_ref.path
    path = bf.file_ref.path
    if seen_files[path]
      duplicates_to_remove << bf
      puts "Found duplicate: #{path}"
    else
      seen_files[path] = true
    end
  end
end

duplicates_to_remove.each { |bf| build_phase.files.delete(bf) }

# Remove WelcomeView.swift file reference from groups
project.main_group.recursive_children.each do |child|
  if child.respond_to?(:path) && child.path == 'WelcomeView.swift'
    child.remove_from_project
    puts "Removed WelcomeView.swift file reference."
  end
end

project.save
puts "Project cleaned and saved."
