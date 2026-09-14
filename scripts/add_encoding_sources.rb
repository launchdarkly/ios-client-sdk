#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

project = Xcodeproj::Project.open(File.expand_path('../LaunchDarkly.xcodeproj', __dir__))

event_store = project.files.find { |f| f.path == 'EventStore.swift' }
raise 'EventStore.swift missing' unless event_store
service_objects = event_store.parent

ld_context = project.files.find { |f| f.path == 'LDContext.swift' }
raise 'LDContext.swift missing' unless ld_context
context_group = ld_context.parent

to_add = [
  [service_objects, 'EventJSONWriter.swift'],
  [service_objects, 'ContextEncodingCache.swift'],
  [service_objects, 'SQLiteEventStore.swift'],
  [context_group, 'LDContextJSONWriter.swift']
]

refs = to_add.map do |group, name|
  existing = group.files.find { |f| f.path == name }
  next existing if existing
  group.new_file(name)
end

sdk_targets = project.targets.select do |t|
  t.source_build_phase.files_references.any? { |f| f.path == 'EventStore.swift' }
end

sdk_targets.each do |target|
  refs.each do |ref|
    next if target.source_build_phase.files_references.include?(ref)
    target.source_build_phase.add_file_reference(ref)
    puts "added #{ref.path} to #{target.name}"
  end
end

project.save
