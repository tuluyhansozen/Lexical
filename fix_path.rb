require 'xcodeproj'
project = Xcodeproj::Project.open('Lexical.xcodeproj')
target = project.targets.find { |t| t.name == 'LexicalCore' }

# Find the mistakenly added file and remove 
file_refs = target.source_build_phase.files_references.select { |f| f.path == 'View+IfAvailable.swift' || f.name == 'View+IfAvailable.swift' }
file_refs.each do |ref|
  target.source_build_phase.remove_file_reference(ref)
  ref.remove_from_project
end

# Re-add it correctly with the right group
group = project.main_group.find_subpath('LexicalCore/Extensions', true)
real_path = '/Users/tuluyhan/projects/Lexical/LexicalCore/Extensions/View+IfAvailable.swift'
file_ref = group.find_file_by_path('View+IfAvailable.swift') || group.new_reference(real_path)

unless target.source_build_phase.files_references.include?(file_ref)
  target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "Fixed View+IfAvailable.swift reference"
