#
# Be sure to run `pod lib lint Protobuf-iOS.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Protobuf-iOS'
  s.version          = '0.1.0'
  s.summary          = 'Google Protocol Buffer runtime lib'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Google Protocol Buffer runtime Lib for Objective-C
                       DESC

  s.homepage         = 'https://github.com/mewehk/Protobuf-iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'mewehk' => '100992222@qq.com' }
  s.source           = { :git => 'https://github.com/mewehk/Protobuf-iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '7.0'

  s.source_files = 'Protobuf-iOS/**/*'
  s.public_header_files = 'Protobuf-iOS/**/*.h'

end
