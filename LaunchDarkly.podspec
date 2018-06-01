Pod::Spec.new do |s|

  s.name         = "LaunchDarkly"
  s.version      = "2.13.0"
  s.summary      = "iOS SDK for LaunchDarkly"

  s.description  = <<-DESC
                   LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
                   * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
                   * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
                   * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
                   * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
                   DESC

  s.homepage     = "https://github.com/launchdarkly/ios-client"

  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }

  s.author             = { "LaunchDarkly" => "team@launchdarkly.com" }

  s.ios.deployment_target     = "8.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target    = "9.0"
  s.osx.deployment_target     = '10.10'

  s.source       = { :git => "https://github.com/launchdarkly/ios-client.git", :tag => "2.13.0" }

  s.source_files  = 'Darkly/**/*.{h,m}'

  s.requires_arc = true

  s.xcconfig	= { 'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS' => 'NO' }

  s.subspec 'Core' do |eventSource|
    eventSource.dependency 'DarklyEventSource', '~>3.2.4'
  end
end
