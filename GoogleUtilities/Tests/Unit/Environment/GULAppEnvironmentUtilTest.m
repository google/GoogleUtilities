// Copyright 2018 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULAppEnvironmentUtil.h"

@interface GULAppEnvironmentUtilTest : XCTestCase

@property(nonatomic) id processInfoMock;

@end

@implementation GULAppEnvironmentUtilTest

- (void)setUp {
  [super setUp];

  _processInfoMock = OCMPartialMock([NSProcessInfo processInfo]);
}

- (void)tearDown {
  [super tearDown];

  [_processInfoMock stopMocking];
}

- (void)testSystemVersionInfoMajorOnly {
#if TARGET_OS_IOS
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion],
                        [UIDevice currentDevice].systemVersion);
#else
  NSOperatingSystemVersion osTen = {.majorVersion = 10, .minorVersion = 0, .patchVersion = 0};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTen);
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion], @"10.0");
#endif
}

- (void)testSystemVersionInfoMajorMinor {
#if TARGET_OS_IOS
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion],
                        [UIDevice currentDevice].systemVersion);
#else
  NSOperatingSystemVersion osTenTwo = {.majorVersion = 10, .minorVersion = 2, .patchVersion = 0};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTenTwo);
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion], @"10.2");
#endif
}

- (void)testSystemVersionInfoMajorMinorPatch {
#if TARGET_OS_IOS
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion],
                        [UIDevice currentDevice].systemVersion);
#else
  NSOperatingSystemVersion osTenTwoOne = {.majorVersion = 10, .minorVersion = 2, .patchVersion = 1};
  OCMStub([self.processInfoMock operatingSystemVersion]).andReturn(osTenTwoOne);
  XCTAssertEqualObjects([GULAppEnvironmentUtil systemVersion], @"10.2.1");
#endif
}

- (void)testDeploymentType {
#if SWIFT_PACKAGE
  NSString *deploymentType = @"swiftpm";
#elif FIREBASE_BUILD_CARTHAGE
  NSString *deploymentType = @"carthage";
#elif FIREBASE_BUILD_ZIP_FILE
  NSString *deploymentType = @"zip";
#elif COCOAPODS
  NSString *deploymentType = @"cocoapods";
#else
  NSString *deploymentType = @"unknown";
#endif

  XCTAssertEqualObjects([GULAppEnvironmentUtil deploymentType], deploymentType);
}

- (void)testApplePlatform {
  // The below ordering is important. For example, both `TARGET_OS_MACCATALYST`
  // and `TARGET_OS_IOS` are `true` when building a macCatalyst app.
#if TARGET_OS_MACCATALYST
  NSString *expectedPlatform = @"maccatalyst";
#elif TARGET_OS_IOS
  NSString *expectedPlatform = @"ios";
#elif TARGET_OS_TV
  NSString *expectedPlatform = @"tvos";
#elif TARGET_OS_OSX
  NSString *expectedPlatform = @"macos";
#elif TARGET_OS_WATCH
  NSString *expectedPlatform = @"watchos";
#endif  // TARGET_OS_MACCATALYST

#if TARGET_OS_VISION
  NSString *expectedPlatform = @"visionos";
#endif  // TARGET_OS_VISION

  XCTAssertEqualObjects([GULAppEnvironmentUtil applePlatform], expectedPlatform);
}

- (void)testAppleDevicePlatform {
  // When a Catalyst app is run on macOS then both `TARGET_OS_MACCATALYST` and `TARGET_OS_IOS` are
  // `true`.
#if TARGET_OS_MACCATALYST
  NSString *expectedPlatform = @"maccatalyst";
#elif TARGET_OS_IOS
  NSString *expectedPlatform = @"ios";

  if ([[UIDevice currentDevice].model.lowercaseString containsString:@"ipad"] ||
      [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    expectedPlatform = @"ipados";
  }
#endif  // TARGET_OS_MACCATALYST

#if TARGET_OS_TV
  NSString *expectedPlatform = @"tvos";
#endif  // TARGET_OS_TV

#if TARGET_OS_OSX
  NSString *expectedPlatform = @"macos";
#endif  // TARGET_OS_OSX

#if TARGET_OS_WATCH
  NSString *expectedPlatform = @"watchos";
#endif  // TARGET_OS_WATCH

#if TARGET_OS_VISION
  NSString *expectedPlatform = @"visionos";
#endif  // TARGET_OS_VISION

  XCTAssertEqualObjects([GULAppEnvironmentUtil appleDevicePlatform], expectedPlatform);
}

@end
