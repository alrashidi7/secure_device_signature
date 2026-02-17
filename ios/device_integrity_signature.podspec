Pod::Spec.new do |s|
  s.name             = 'device_integrity_signature'
  s.version          = '1.0.0'
  s.summary          = 'Persistent hardware device signature with integrity checks'
  s.description      = <<-DESC
  Generates a persistent, hardware-bound device signature. Uses Keychain on iOS
  and MediaDrm/Keystore on Android. Includes root/jailbreak and emulator detection.
                       DESC
  s.homepage         = 'https://github.com/your-org/device_integrity_signature'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Diyar' => 'dev@diyar.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '12.0'
  s.swift_version    = '5.0'
end
