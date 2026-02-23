require 'xcodeproj'

project = Xcodeproj::Project.open('Lexical.xcodeproj')
target = project.targets.find { |t| t.name == 'Lexical' }

if target
  target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_KEY_UIRequiresFullScreen'] = 'YES'
  end
  project.save
  puts "Successfully added UIRequiresFullScreen=YES to Lexical target."
else
  puts "Target Lexical not found."
end
