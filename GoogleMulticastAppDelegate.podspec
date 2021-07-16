Pod::Spec.new do |s|
  # TODO: Is `GoogleMulticastAppDelegate` name fine?
  s.name             = 'GoogleMulticastAppDelegate'
  s.version          = '7.5.0'
  s.summary          = 'GoogleMulticastAppDelegate'

  s.description      = <<-DESC
  GoogleMulticastAppDelegate
                       DESC

  s.homepage         = 'https://github.com/google/GoogleUtilities'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/google/GoogleUtilities.git',
    :tag => 'MulticastAppDelegate-' + s.version.to_s
  }

  ios_deployment_target = '9.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  # s.osx.deployment_target = osx_deployment_target
  # s.tvos.deployment_target = tvos_deployment_target
  # s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  base_dir = "GoogleMulticastAppDelegate/"
  s.source_files = [
    base_dir + 'Sources/**/*.swift',
  ]

  # s.test_spec 'unit' do |unit_tests|
  #   unit_tests.scheme = { :code_coverage => true }
  #   unit_tests.platforms = {
  #     :ios => ios_deployment_target,
  #     :osx => osx_deployment_target,
  #     :tvos => tvos_deployment_target
  #   }
  #   unit_tests.source_files = [
  #     base_dir + 'Tests/Unit/**/*.[mh]',
  #   ]
  #   unit_tests.requires_app_host = true
  #   unit_tests.dependency 'OCMock'
  # end

  # s.test_spec 'unit-swift' do |unit_tests_swift|
  #   unit_tests_swift.scheme = { :code_coverage => true }
  #   unit_tests_swift.platforms = {
  #     :ios => ios_deployment_target,
  #     :osx => osx_deployment_target,
  #     :tvos => tvos_deployment_target
  #   }
  #   unit_tests_swift.source_files = [
  #     base_dir + 'Tests/Unit/**/*.swift',
  #   ]

  #   unit_tests_swift.requires_app_host = true
  # end
end
