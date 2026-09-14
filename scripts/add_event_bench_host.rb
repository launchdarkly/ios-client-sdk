#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

project_path = File.expand_path('../LaunchDarkly.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'EventBenchHost' }
  puts 'EventBenchHost already exists'
  exit 0
end

group = project.main_group.find_subpath('EventBenchHost', true)
group.set_source_tree('<group>')
group.set_path('EventBenchHost')
app_ref = group.new_file('App.swift')

host = project.new_target(:application, 'EventBenchHost', :ios, '13.0', project.products_group, :swift)
host.add_file_references([app_ref])

ios_sdk = project.targets.find { |t| t.name == 'LaunchDarkly_iOS' }
raise 'LaunchDarkly_iOS target missing' unless ios_sdk

host.add_dependency(ios_sdk)

# Embed the SDK so @testable import LaunchDarkly can load it inside the host.
embed = host.new_copy_files_build_phase('Embed Frameworks')
embed.dst_subfolder_spec = '10' # Frameworks
embed.add_file_reference(ios_sdk.product_reference, true)
embed.files.each do |build_file|
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
end

host.frameworks_build_phase.add_file_reference(ios_sdk.product_reference)

host.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.launchdarkly.EventBenchHost'
  s['DEVELOPMENT_TEAM'] = '53D32B66PT'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CODE_SIGN_IDENTITY'] = 'Apple Development'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'EventBenchHost'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SDKROOT'] = 'iphoneos'
  s['SWIFT_VERSION'] = '5.0'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  if config.name == 'Release'
    s['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    s['SWIFT_COMPILATION_MODE'] = 'wholemodule'
  else
    s['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  end
end

tests = project.targets.find { |t| t.name == 'LaunchDarklyTests' }
raise 'LaunchDarklyTests target missing' unless tests

tests.add_dependency(host)
tests.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/EventBenchHost.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/EventBenchHost'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
end

project.save
puts "Added EventBenchHost (#{host.uuid})"
puts "LaunchDarklyTests uuid=#{tests.uuid}"
