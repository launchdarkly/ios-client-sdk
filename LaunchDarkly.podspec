Pod::Spec.new do |s|

  s.name         = "LaunchDarkly"
  s.version      = "2.2.0"
  s.summary      = "iOS SDK for LaunchDarkly"

  s.description  = <<-DESC
                   A longer description of darkly in Markdown format.

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.homepage     = "https://github.com/launchdarkly/ios-client"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }

  s.author             = { "LaunchDarkly" => "team@launchdarkly.com" }

  s.ios.deployment_target     = "8.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target    = "9.0"
  s.osx.deployment_target     = '10.10'

  s.source       = { :git => "https://github.com/launchdarkly/ios-client.git", :tag => "2.2.0" }

  s.source_files  = "Darkly/*.{h,m}"

  s.requires_arc = true

  s.subspec 'Core' do |ss|
    ss.dependency 'DarklyEventSource', '~> 1.3.1'
  end
end
