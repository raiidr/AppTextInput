require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "AppTextInput"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.1" }
  s.source       = { :git => package["repository"], :tag => "#{s.version}" }

  s.source_files = "ios/AppTextInput/**/*.{h,m,mm,swift}"
  # Exclude the Fabric component view files. The new architecture is supported
  # through the legacy view manager interop layer, which avoids the C++ header
  # / module map failures caused by `use_frameworks!` in React Native 0.74+.
  s.exclude_files = [
    "ios/AppTextInput/**/*_v0.{h,m,mm,swift}",
    "ios/AppTextInput/AppTextInputComponentView.{h,mm}"
  ]
  s.resource_bundles = {
    "AppTextInput" => ["ios/AppTextInput/PrivacyInfo.xcprivacy"]
  }

  s.dependency "React-Core"
  s.dependency "lottie-ios", "~> 4.5.0"

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_COMPILATION_MODE" => "wholemodule",
    "OTHER_LDFLAGS" => "$(inherited) -ObjC"
  }
end
