require 'xcodeproj'
project = Xcodeproj::Project.open('Lexical.xcodeproj')
target = project.targets.find { |t| t.name == 'LexicalCore' }
group = project.main_group.find_subpath('LexicalCore/Extensions', true)
file_ref = group.find_file_by_path('View+IfAvailable.swift') || group.new_file('View+IfAvailable.swift')
unless target.source_build_phase.files_references.include?(file_ref)
  target.source_build_phase.add_file_reference(file_ref)
end
project.save
puts "Added View+IfAvailable.swift"
