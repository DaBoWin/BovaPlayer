Pod::Spec.new do |s|
  s.name             = 'media_kit_libs_macos_video'
  s.version          = '1.0.4'
  s.summary          = 'Full flavor MPV library for macOS with TrueHD support'
  s.homepage         = 'https://github.com/media-kit/media-kit'
  s.license          = { :type => 'LGPL-2.1' }
  s.author           = { 'BovaPlayer' => 'bova@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.13'
  s.vendored_frameworks = 'Frameworks/*.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
