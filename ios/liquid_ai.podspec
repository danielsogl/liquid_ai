Pod::Spec.new do |s|
  s.name             = 'liquid_ai'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Liquid AI with LEAP SDK integration.'
  s.description      = <<-DESC
A Flutter plugin that provides AI integrations using the LEAP SDK for on-device
model inference on iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/danielsogl/liquid_ai'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Daniel Sogl' => 'daniel@sogl.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'liquid_ai/Sources/liquid_ai/**/*.swift'
  s.dependency 'Flutter'
  # Note: For CocoaPods users, Leap-SDK must be added manually to the Podfile.
  # We recommend using Swift Package Manager instead for easier integration.
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
