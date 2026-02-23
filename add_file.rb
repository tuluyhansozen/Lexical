require 'xcodeproj'
project = Xcodeproj::Project.open('Lexical.xcodeproj')
target = project.targets.first
group = project.main_group.find_subpath('Lexical/Features/Dashboard', true)
file_ref = group.find_file_by_path('ActivityGridMonth.swift') || group.new_file('ActivityGridMonth.swift')
unless target.source_build_phase.files_references.include?(file_ref)
  target.source_build_phase.add_file_reference(file_ref)
end
project.save
puts "Added ActivityGridMonth.swift"
