use_frameworks!
workspace 'Darkly.xcworkspace'
target 'Darkly_iOS' do
    platform :ios, '8.0'
    pod 'SwiftLint', '0.28.2'
    pod 'DarklyEventSource', '3.2.7'
end

target 'Darkly_watchOS' do
    platform :watchos, '2.0'
    pod 'SwiftLint', '0.28.2'
    pod 'DarklyEventSource', '3.2.7'
end

target 'Darkly_macOS' do
    platform :osx, '10.10'
    pod 'SwiftLint', '0.28.2'
    pod 'DarklyEventSource', '3.2.7'
end

target 'Darkly_tvOS' do
    platform :tvos, '9.0'
    pod 'SwiftLint', '0.28.2'
    pod 'DarklyEventSource', '3.2.7'
end

target 'DarklyTests' do
    platform :ios, '8.0'
    pod 'OHHTTPStubs/Swift', '6.1.0'
#todo: when updating Quick to a later version, try to remove the warning inhibitor
    pod 'Quick', '1.3.2', :inhibit_warnings => true
    pod 'Nimble', '7.3.1'
    pod 'Sourcery', '0.15.0'
end
