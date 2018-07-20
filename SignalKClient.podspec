#
# Be sure to run `pod lib lint SignalKClient.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SignalKClient'
  s.version          = '0.4.2'
  s.summary          = 'Client Library For Accessing Signal K Servers From an iOS Application.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Client Library For Accessing Signal K Servers From an iOS Application
                       DESC

  s.homepage         = 'https://github.com/SignalK/signalk-ios-client'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'scott@scottbender.net' => 'scott@scottbender.net' }
  s.source           = { :git => 'https://github.com/SignalK/signalk-ios-client.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.3'
  s.osx.deployment_target = '10.10'

  s.source_files = 'SignalKClient/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SignalKClient' => ['SignalKClient/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'SocketRocket', '~> 0.5.1' 
end
