Pod::Spec.new do |s|
	s.name         = "DarklyEventSource"
	s.version      = "3.2.5"
	s.summary      = "HTML5 Server-Sent Events in your Cocoa app."
	s.homepage     = "https://github.com/launchdarkly/ios-eventsource"
	s.license      = 'MIT (see LICENSE.txt)'
	s.author       = { "Neil Cowburn" => "git@neilcowburn.com" }
	s.source       = { :git => "https://github.com/launchdarkly/ios-eventsource.git", :tag => '3.2.5' }
	s.source_files = 'LDEventSource', 'LDEventSource/LDEventSource.{h,m}'
	s.ios.deployment_target = '8.0'
	s.osx.deployment_target = '10.10'
	s.watchos.deployment_target = '2.0'
	s.tvos.deployment_target = '9.0'
	s.requires_arc = true
	s.xcconfig = { 'OTHER_LDFLAGS' => '-lobjc' }
end
