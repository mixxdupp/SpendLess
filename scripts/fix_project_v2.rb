require 'xcodeproj'

project_path = 'SpendLess.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'SpendLess'
target = project.targets.find { |t| t.name == target_name }

def fix_file(project, target, relative_path)
  filename = File.basename(relative_path)
  
  # 1. Remove ANY existing file references that match the filename
  # This cleans up the broken references from previous attempt
  project.files.select { |f| f.path == filename || f.name == filename }.each do |f|
    puts "Removing broken ref: #{f.path}"
    f.remove_from_project
  end

  # 2. Add the file to the MAIN GROUP using the full relative path
  # This ensures Xcode knows exactly where it is on disk
  puts "Adding correct ref: #{relative_path}"
  file_ref = project.main_group.new_file(relative_path)
  
  # 3. Add to target source build phase if not present
  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
    puts "Added to target"
  else
    puts "Already in target"
  end
end

fix_file(project, target, 'Sources/SpendLess/Models/Wishlist.swift')
fix_file(project, target, 'Sources/SpendLess/Views/RationalityChatView.swift')

project.save
puts "Project repaired."
