Pod::Spec.new do |s|
  s.name             = 'loginflow_auth'
  s.version          = '0.1.0'
  s.summary          = 'LoginFlow client: secure storage, Native SSO keychain sharing and the system browser.'
  s.description      = <<-DESC
Native side of the loginflow_auth Flutter plugin: private Keychain storage,
a shared Keychain access group for OpenID Connect Native SSO, and
ASWebAuthenticationSession for browser steps.
                       DESC
  s.homepage         = 'https://github.com/LoginFlow/loginflow_auth'
  s.license          = { :type => 'Proprietary', :text => 'Copyright LoginFlow. All rights reserved.' }
  s.author           = 'LoginFlow'
  s.source           = { :path => '.' }
  s.source_files     = 'loginflow_auth/Sources/loginflow_auth/**/*.swift'
  s.resource_bundles = { 'loginflow_auth_privacy' => ['loginflow_auth/Sources/loginflow_auth/PrivacyInfo.xcprivacy'] }
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
