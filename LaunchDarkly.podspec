# coding: utf-8
Pod::Spec.new do |ld|

  ld.name         = "LaunchDarkly"
  ld.version      = "5.3.2"
  ld.summary      = "iOS SDK for LaunchDarkly"

  ld.description  = <<-DESC
                   LaunchDarkly is the feature management platform that software teams use to build better software, faster. Development teams use feature management as a best practice to separate code deployments from feature releases. With LaunchDarkly teams control their entire feature lifecycles from concept to launch to value.
                   With LaunchDarkly, you can:
                   * Release a new feature to a subset of your users, like a group of users who opt-in to a beta tester group.
                   * Slowly roll out a feature to an increasing percentage of users and track the effect that feature has on key metrics.
                   * Instantly turn off a feature that is causing problems, without re-deploying code or restarting the application with a changed config file.
                   * Maintain granular control over your users’ experience by granting access to certain features based on any attribute you choose. For example, provide different users with different functionality based on their payment plan.
                   * Disable parts of your application to facilitate maintenance, without taking everything offline.
                   DESC

  ld.homepage     = "https://github.com/launchdarkly/ios-client-sdk"

  ld.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE.txt" }

  ld.author       = { "LaunchDarkly" => "sdks@launchdarkly.com" }

  ld.ios.deployment_target     = "10.0"
  ld.watchos.deployment_target = "3.0"
  ld.tvos.deployment_target    = "10.0"
  ld.osx.deployment_target     = "10.12"

  ld.source       = { :git => ld.homepage + '.git', :tag => ld.version}

  ld.source_files = "LaunchDarkly/LaunchDarkly/**/*.{h,m,swift}"

  ld.requires_arc = true

  ld.swift_version = '5.0'

  ld.subspec 'Core' do |es|
    es.dependency 'LDSwiftEventSource', '1.2.1'
  end
end
