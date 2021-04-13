Pod::Spec.new do |s|
  s.name             = 'GoogleUtilities'
  s.version          = '7.4.0'
  s.summary          = 'Google Utilities for Apple platform SDKs'

  s.description      = <<-DESC
Internal Google Utilities including Network, Reachability Environment, Logger and Swizzling for
other Google CocoaPods. They're not intended for direct public usage.
                       DESC

  s.homepage         = 'https://github.com/google/GoogleUtilities'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/google/GoogleUtilities.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  ios_deployment_target = '9.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.subspec 'Environment' do |es|
    es.source_files = 'GoogleUtilities/Environment/**/*.[mh]'
    es.public_header_files = 'GoogleUtilities/Environment/Public/GoogleUtilities/*.h'
    es.dependency 'PromisesObjC', '~> 1.2'
    es.frameworks = [
      'Security'
    ]
  end

  s.subspec 'Logger' do |ls|
    ls.source_files = 'GoogleUtilities/Logger/**/*.[mh]'
    ls.public_header_files = 'GoogleUtilities/Logger/Public/GoogleUtilities/*.h'
    ls.dependency 'GoogleUtilities/Environment'
  end


  s.subspec 'Network' do |ns|
    ns.source_files = 'GoogleUtilities/Network/**/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/Network/Public/GoogleUtilities/*.h'
    ns.dependency 'GoogleUtilities/NSData+zlib'
    ns.dependency 'GoogleUtilities/Logger'
    ns.dependency 'GoogleUtilities/Reachability'
    ns.frameworks = [
      'Security'
    ]
  end

  s.subspec 'NSData+zlib' do |ns|
    ns.source_files = 'GoogleUtilities/NSData+zlib/**/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/NSData+zlib/Public/GoogleUtilities/*.h'
    ns.libraries = [
      'z'
    ]
  end

  s.subspec 'Reachability' do |rs|
    rs.source_files = 'GoogleUtilities/Reachability/**/*.[mh]'
    rs.public_header_files = 'GoogleUtilities/Reachability/Public/GoogleUtilities/*.h'
    rs.ios.frameworks = [
      'SystemConfiguration'
    ]
    rs.osx.frameworks = [
      'SystemConfiguration'
    ]
    rs.tvos.frameworks = [
      'SystemConfiguration'
    ]
    rs.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'AppDelegateSwizzler' do |adss|
    adss.source_files = [
      'GoogleUtilities/AppDelegateSwizzler/Internal/*.h',
      'GoogleUtilities/AppDelegateSwizzler/Public/**/*.h',
      'GoogleUtilities/AppDelegateSwizzler/*.m',
      'GoogleUtilities/Common/*.h',
    ]
    adss.public_header_files = [
      'GoogleUtilities/AppDelegateSwizzler/Public/GoogleUtilities/*.h',
    ]
    adss.dependency 'GoogleUtilities/Logger'
    adss.dependency 'GoogleUtilities/Network'
    adss.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'ISASwizzler' do |iss|
    iss.source_files = 'GoogleUtilities/ISASwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    iss.public_header_files = 'GoogleUtilities/ISASwizzler/Public/GoogleUtilities/*.h'
  end

  s.subspec 'MethodSwizzler' do |mss|
    mss.source_files = 'GoogleUtilities/MethodSwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    mss.public_header_files = 'GoogleUtilities/MethodSwizzler/Public/GoogleUtilities/*.h'
    mss.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'SwizzlerTestHelpers' do |sths|
    sths.source_files = 'GoogleUtilities/SwizzlerTestHelpers/**/*.[hm]'
    sths.public_header_files = 'GoogleUtilities/SwizzlerTestHelpers/Public/GoogleUtilities/*.h'
    sths.dependency 'GoogleUtilities/MethodSwizzler'
  end

  s.subspec 'UserDefaults' do |ud|
    ud.source_files = 'GoogleUtilities/UserDefaults/**/*.[hm]'
    ud.public_header_files = 'GoogleUtilities/UserDefaults/Public/GoogleUtilities/*.h'
    ud.dependency 'GoogleUtilities/Logger'
  end

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    # All tests require arc except Tests/Network/third_party/GTMHTTPServer.m
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      'GoogleUtilities/Tests/Unit/**/*.[mh]',
    ]
    unit_tests.requires_arc = 'GoogleUtilities/Tests/Unit/*/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end

  s.test_spec 'unit-swift' do |unit_tests_swift|
    unit_tests_swift.scheme = { :code_coverage => true }
    unit_tests_swift.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests_swift.source_files = 'GoogleUtilities/Tests/SwiftUnit/**/*.swift',
                                    'GoogleUtilities/Tests/SwiftUnit/**/*.h'
    unit_tests_swift.requires_app_host = true
  end
end
