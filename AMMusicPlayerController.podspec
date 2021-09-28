Pod::Spec.new do |s|
  s.name = "AMMusicPlayerController"
  s.version = "0.1.3"
  s.summary = "AMMusicPlayerController is an UI Controller with Apple Music-ish Player."
  s.homepage = "https://github.com/damoncoo/AMMusicPlayerController.git"
  s.source = { :git => "https://github.com/damoncoo/AMMusicPlayerController.git", :tag => s.version }
  s.license = { :type => "MIT", :file => "LICENSE" }

  s.author = { "yoheimuta" => "yoheimuta" }

  s.platform = :ios
  s.ios.framework = "UIKit"
  s.swift_version = ["4.2", "5.0"]
  s.ios.deployment_target = "10.0"

  s.source_files = "AMMusicPlayerController/*.{swift,h,storyboard}"
  s.resource = "AMMusicPlayerController/Media.xcassets"
  s.dependency "RxMusicPlayer", "1.0.0"
  s.dependency "SPStorkController"
end
