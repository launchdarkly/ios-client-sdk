require 'json'

# expect package.json in current dir
package_json_filename = File.expand_path("./package.json", __dir__)

# load the spec from package.json
package = JSON.load(File.read(package_json_filename))

Pod::Spec.new do |s|
  s.name     = package['name']
  s.version  = package['version']
  s.summary  = package['description']
  s.homepage = package['homepage']
  s.license  = package['license']
  s.author   = package['author']
  s.source   = { :git => package['repository']['url'], :tag => "v#{s.version}" }
  s.platform = :ios, "8.0"
  s.preserve_paths = 'README.md', 'LICENSE', 'package.json'
  s.source_files   = "ios/RNLaunchDarkly/*.{h,m}"
  s.requires_arc = true
  s.dependency 'LaunchDarkly'
  s.dependency 'React'
end