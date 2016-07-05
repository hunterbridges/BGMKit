#
# Be sure to run `pod lib lint BGMKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BGMKit'
  s.version          = '0.1.6'
  s.summary          = 'Configurable OGG music loops for iOS applications.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The fun and quirky way to play music in your app.
                       DESC

  s.homepage         = 'https://github.com/hunterbridges/BGMKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Hunter Bridges' => 'hbridges@gmail.com' }
  s.source           = { :git => 'https://github.com/hunterbridges/BGMKit.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/hunterbridges'

  s.ios.deployment_target = '8.0'

  s.source_files = 'BGMKit/{Classes,include,Ogg,Vorbis}/**/*.{h,m,c}'

  s.public_header_files = 'Pod/Classes/**/*.h'
  s.private_header_files = 'Pod/{include,Vorbis}/*.h'
  s.frameworks = 'AVFoundation', 'AudioToolbox'
end
