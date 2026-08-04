// Copyright 2019 Google LLC
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

#import "GoogleUtilities/AppDelegateSwizzler/Internal/GULSceneDelegateSwizzler_Private.h"
#import "GoogleUtilities/AppDelegateSwizzler/Public/GoogleUtilities/GULSceneDelegateSwizzler.h"

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

/** Plist key that allows Firebase developers to disable Scene Delegate Proxying.  Source of truth
 * is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULFirebaseSceneDelegateProxyEnabledPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

/** Plist key that allows non-Firebase developers to disable Scene Delegate Proxying.  Source of
 * truth is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULGoogleSceneDelegateProxyEnabledPlistKey =
    @"GoogleUtilitiesAppDelegateProxyEnabled";

#pragma mark - Scene Delegate

#if UISCENE_SUPPORTED

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
@protocol TestSceneProtocol <UISceneDelegate>
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface GULTestSceneDelegate : NSObject <UISceneDelegate>
@end

@implementation GULTestSceneDelegate
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface GULFakeSceneDelegateInterceptor : NSObject <UISceneDelegate>
@property(nonatomic) dispatch_queue_t syncQueue;
@property(nonatomic) BOOL isSceneWillConnectToSessionOptionsCalled;
@property(nonatomic) BOOL isSceneOpenURLContextsCalled;
@end

@implementation GULFakeSceneDelegateInterceptor
- (instancetype)init {
  self = [super init];
  if (self) {
    _syncQueue = dispatch_queue_create("GULFakeSceneDelegateInterceptor", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
  dispatch_sync(_syncQueue, ^{
    self->_isSceneWillConnectToSessionOptionsCalled = YES;
  });
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
  dispatch_sync(_syncQueue, ^{
    self->_isSceneOpenURLContextsCalled = YES;
  });
}
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface GULFakeScene : NSObject
@property(nonatomic, weak) id<UISceneDelegate> delegate;
@end

@implementation GULFakeScene
@synthesize delegate = _delegate;
@end

static NSDictionary *gSceneFakeInfoDictionary = nil;

@interface NSBundle (SceneFakeInfoDictionary)
- (NSDictionary *)gul_scene_fakeInfoDictionary;
@end

@implementation NSBundle (SceneFakeInfoDictionary)
- (NSDictionary *)gul_scene_fakeInfoDictionary {
  if (gSceneFakeInfoDictionary) return gSceneFakeInfoDictionary;
  return [self gul_scene_fakeInfoDictionary];
}
@end

@interface GULSceneDelegateSwizzlerTest : XCTestCase
@end

@implementation GULSceneDelegateSwizzlerTest

- (void)setUp {
  [super setUp];
  Method originalBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
  Method swizzledBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(gul_scene_fakeInfoDictionary));
  method_exchangeImplementations(originalBundleMethod, swizzledBundleMethod);
}

- (void)tearDown {
  [GULSceneDelegateSwizzler clearInterceptors];
  Method originalBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
  Method swizzledBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(gul_scene_fakeInfoDictionary));
  method_exchangeImplementations(originalBundleMethod, swizzledBundleMethod);
  gSceneFakeInfoDictionary = nil;
  [super tearDown];
}

- (void)testProxySceneDelegateWithNoSceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    GULFakeScene *mockSharedScene = [[GULFakeScene alloc] init];
    mockSharedScene.delegate = nil;
    XCTAssertNoThrow(
        [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:(UIScene *)mockSharedScene]);
  }
}

- (void)testProxySceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    GULFakeScene *mockSharedScene = [[GULFakeScene alloc] init];
    mockSharedScene.delegate = realSceneDelegate;
    size_t sizeBefore = class_getInstanceSize([GULTestSceneDelegate class]);

    Class realSceneDelegateClassBefore = [realSceneDelegate class];

    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:(UIScene *)mockSharedScene];

    XCTAssertTrue([realSceneDelegate isKindOfClass:[GULTestSceneDelegate class]]);

    NSString *newClassName = NSStringFromClass([realSceneDelegate class]);
    XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
    // It is no longer GULTestSceneDelegate class instance.
    XCTAssertFalse([realSceneDelegate isMemberOfClass:[GULTestSceneDelegate class]]);

    size_t sizeAfter = class_getInstanceSize([realSceneDelegate class]);

    // Class size must stay the same.
    XCTAssertEqual(sizeBefore, sizeAfter);

    // After being proxied, it should be able to respond to the required method selector.
    XCTAssertTrue([realSceneDelegate respondsToSelector:@selector(scene:openURLContexts:)]);

    // Make sure that the class has changed.
    XCTAssertNotEqualObjects([realSceneDelegate class], realSceneDelegateClassBefore);
  }
}

- (void)testProxyProxiedSceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    GULFakeScene *mockSharedScene = [[GULFakeScene alloc] init];
    mockSharedScene.delegate = realSceneDelegate;

    // Proxy the scene delegate for the 1st time.
    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:(UIScene *)mockSharedScene];

    Class realSceneDelegateClassBefore = [realSceneDelegate class];

    // Proxy the scene delegate for the 2nd time.
    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:(UIScene *)mockSharedScene];

    // Make sure that the class isn't changed.
    XCTAssertEqualObjects([realSceneDelegate class], realSceneDelegateClassBefore);
  }
}

- (void)testSceneOpenURLContextsIsInvokedOnInterceptors {
  if (@available(iOS 13, tvOS 13, *)) {
    NSSet *urlContexts = [NSSet set];

    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    GULFakeScene *mockSharedScene = [[GULFakeScene alloc] init];
    mockSharedScene.delegate = realSceneDelegate;

    GULFakeSceneDelegateInterceptor *interceptor = [[GULFakeSceneDelegateInterceptor alloc] init];

    GULFakeSceneDelegateInterceptor *interceptor2 = [[GULFakeSceneDelegateInterceptor alloc] init];

    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:(UIScene *)mockSharedScene];

    [GULSceneDelegateSwizzler registerSceneDelegateInterceptor:interceptor];
    [GULSceneDelegateSwizzler registerSceneDelegateInterceptor:interceptor2];

    [realSceneDelegate scene:(UIScene *)mockSharedScene openURLContexts:urlContexts];
    __block BOOL isCalled1 = NO;
    __block BOOL isCalled2 = NO;
    dispatch_sync(interceptor.syncQueue, ^{
      isCalled1 = interceptor.isSceneOpenURLContextsCalled;
    });
    dispatch_sync(interceptor2.syncQueue, ^{
      isCalled2 = interceptor2.isSceneOpenURLContextsCalled;
    });
    XCTAssertTrue(isCalled1);
    XCTAssertTrue(isCalled2);
  }
}

#if !TARGET_OS_MACCATALYST
// Test fails on Catalyst.

- (void)testNotificationCenterRegister {
  if (@available(iOS 13, tvOS 13, *)) {
    [GULSceneDelegateSwizzler proxyOriginalSceneDelegate];

    XCTNSNotificationExpectation *expectation =
        [[XCTNSNotificationExpectation alloc] initWithName:UISceneWillConnectNotification];

    [[NSNotificationCenter defaultCenter]
        postNotification:[NSNotification notificationWithName:UISceneWillConnectNotification
                                                       object:nil]];
    [self waitForExpectations:@[ expectation ] timeout:1];
  }
}
#endif

#pragma mark - Tests to test that Plist flag is honored

/** Tests that scene delegate proxy is enabled when there is no Info.plist dictionary. */
- (void)testAppProxyPlistFlag_NoFlag {
  // No keys anywhere. If there is no key, the default should be enabled.
  NSDictionary *mainDictionary = nil;
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that scene delegate proxy is enabled when there is neither the Firebase nor the
 * non-Firebase Info.plist key present.
 */
- (void)testAppProxyPlistFlag_NoSceneDelegateProxyKey {
  // No scene delegate disable key. If there is no key, the default should be enabled.
  NSDictionary *mainDictionary = @{@"randomKey" : @"randomValue"};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that scene delegate proxy is enabled when the Firebase plist is explicitly set to YES and
 * the Google flag is not present. */
- (void)testAppProxyPlistFlag_FirebaseEnabled {
  // Set proxy enabled to YES.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(YES)};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that scene delegate proxy is enabled when the Google plist is explicitly set to YES and
 * the Firebase flag is not present. */
- (void)testAppProxyPlistFlag_GoogleEnabled {
  // Set proxy enabled to YES.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @(YES)};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is enabled when the Firebase flag has the wrong type of
 * value and the Google flag is not present. */
- (void)testAppProxyPlist_WrongFirebaseDisableFlagValueType {
  // Set proxy enabled to "NO" - a string.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @"NO"};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is enabled when the Google flag has the wrong type of value
 * and the Firebase flag is not present. */
- (void)testAppProxyPlist_WrongGoogleDisableFlagValueType {
  // Set proxy enabled to "NO" - a string.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @"NO"};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is disabled when the Firebase flag is set to NO and the
 * Google flag is not present. */
- (void)testAppProxyPlist_FirebaseDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is not present. */
- (void)testAppProxyPlist_GoogleDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO)};
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to YES. */
- (void)testAppProxyPlist_GoogleDisableFlagFirebaseEnableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(YES)
  };
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to YES. */
- (void)testAppProxyPlist_FirebaseDisableFlagGoogleEnableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(YES),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)
  };
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to NO. */
- (void)testAppProxyPlist_FirebaseDisableFlagGoogleDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)
  };
  gSceneFakeInfoDictionary = mainDictionary;

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  gSceneFakeInfoDictionary = nil;
}

@end

#pragma clang diagnostic pop
#endif  // UISCENE_SUPPORTED
