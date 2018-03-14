Pod::Spec.new do |ld|

  ld.name         = "LaunchDarkly"
  ld.version      = "3.0.0.11"
  ld.summary      = "iOS SDK for LaunchDarkly"

  ld.description  = <<-DESC
                   LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
                   * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
                   * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
                   * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
                   * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
                   DESC

#  ld.homepage     = "https://github.com/launchdarkly/ios-client-swift"	#TODO: Once we release, point this to the public home page
  ld.homepage     = "https://github.com/launchdarkly/ios-client"

  ld.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }

  ld.author             = { "LaunchDarkly" => "team@launchdarkly.com" }

  ld.ios.deployment_target     = "8.0"
#  ld.watchos.deployment_target = "2.0"		#TODO: Uncomment when setting up the watchOS target
#  ld.tvos.deployment_target    = "9.0"		#TODO: Uncomment when setting up the tvOS target
#  ld.osx.deployment_target     = "10.10"	#TODO: Uncomment when setting up the macOS target

  ld.source       = { :git => "https://github.com/launchdarkly/ios-client-swift-private.git" }	#TODO: Add the tag when ready

  ld.source_files  = "Darkly/Darkly/**/*.{h,m,swift}"

  ld.requires_arc = true

  ld.swift_version = '4.0'

  ld.subspec 'Core' do |es|
    es.dependency 'DarklyEventSource', '~> 3.2'
  end
end
