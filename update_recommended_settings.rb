require 'xcodeproj'
require 'fileutils'

project_path = 'Diabo/Diabo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Update project attributes via the root object
project.root_object.attributes['LastSwiftUpdateCheck'] = '1610'
project.root_object.attributes['LastUpgradeCheck'] = '1610'

# 2. Update build settings for project and targets
def apply_recommended_settings(config)
  settings = config.build_settings
  
  # Remove deprecated settings
  settings.delete('VALID_ARCHS')
  
  # Core Recommended Settings
  settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  settings['LOCALIZATION_PREFERS_STRING_CATALOGS'] = 'YES'
  settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
  
  # Warning Flags (modern defaults)
  settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'YES'
  settings['CLANG_WARN_STRICT_PROTOTYPES'] = 'YES'
  settings['CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF'] = 'YES'
  settings['CLANG_ANALYZER_NONNULL'] = 'YES'
  settings['CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION'] = 'YES_AGGRESSIVE'
  settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'YES'
  settings['CLANG_WARN_UNGUARDED_AVAILABILITY'] = 'YES_AGGRESSIVE'
  settings['GCC_WARN_ABOUT_RETURN_TYPE'] = 'YES_ERROR'
  settings['CLANG_WARN_OBJC_ROOT_CLASS'] = 'YES_ERROR'
  
  # Target Specifics
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
end

# Apply to project-level configurations
project.build_configurations.each { |config| apply_recommended_settings(config) }

# Apply to all target-level configurations
project.targets.each do |target|
  target.build_configurations.each { |config| apply_recommended_settings(config) }
end

project.save
puts "Successfully updated project attributes and build settings to modern recommended values."
