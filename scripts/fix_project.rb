require 'xcodeproj'

project_path = 'SpendLess.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'SpendLess'
target = project.targets.find { |t| t.name == target_name }

unless target
  puts "Target #{target_name} not found!"
  exit 1
end

def add_file_to_target(project, target, group_path, file_name)
  # Traverse to group
  current_group = project.main_group
  group_path.split('/').each do |sub_group_name|
    # Find existing group or create new one
    found = current_group.children.find { |c| c.isa == 'PBXGroup' && c.name == sub_group_name } || 
            current_group.children.find { |c| c.isa == 'PBXGroup' && c.path == sub_group_name }
    
    if found
      current_group = found
    else
      puts "Creating group #{sub_group_name}"
      current_group = current_group.new_group(sub_group_name)
    end
  end
  
  # Check if file ref exists in group
  file_ref = current_group.files.find { |f| f.path == file_name }
  unless file_ref
    puts "Adding file ref #{file_name} to group #{current_group.name}"
    file_ref = current_group.new_file(file_name)
  end
  
  # Check if in target
  if target.source_build_phase.files_references.include?(file_ref)
    puts "#{file_name} already in compilation target"
  else
    puts "Adding #{file_name} to compilation target"
    target.add_file_references([file_ref])
  end
end

# Fix Wishlist.swift
add_file_to_target(project, target, 'Sources/SpendLess/Models', 'Wishlist.swift')

# Fix RationalityChatView.swift
add_file_to_target(project, target, 'Sources/SpendLess/Views', 'RationalityChatView.swift')

project.save
puts "Project saved successfully!"
