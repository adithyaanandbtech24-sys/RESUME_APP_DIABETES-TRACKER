require 'xcodeproj'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Update root object attributes
project.root_object.attributes['LastSwiftUpdateCheck'] = '1610'
project.root_object.attributes['LastUpgradeCheck'] = '1610'

project.build_configurations.each do |config|
  settings = config.build_settings
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  settings['SWIFT_VERSION'] = '5.0'
  settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'YES'
  settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'YES'
end

project.targets.each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
    settings['SWIFT_VERSION'] = '5.0'
    settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
  end
end

project.save
puts "Recommended project settings applied correctly."
