require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Diabo' }
group = project.main_group.find_subpath('Diabo/Diabo', true)

files_to_add = [
  'OrganSystemLabView.swift',
  'MedicationTrackingView.swift',
  'ComplicationTrackerView.swift',
  'DiabetesAlertEngine.swift'
]

files_to_add.each do |file_name|
  existing_file = group.files.find { |f| f.path == file_name }
  if existing_file
    puts "#{file_name} already exists in project."
  else
    file_ref = group.new_reference(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name} to project."
  end
end

project.save
puts "Project saved."
