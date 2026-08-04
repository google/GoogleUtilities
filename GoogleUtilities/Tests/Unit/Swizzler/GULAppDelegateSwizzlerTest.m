// Copyright 2018 Google LLC
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

#import "GoogleUtilities/AppDelegateSwizzler/Internal/GULAppDelegateSwizzler_Private.h"
#import "GoogleUtilities/AppDelegateSwizzler/Public/GoogleUtilities/GULAppDelegateSwizzler.h"

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#if (defined(__IPHONE_9_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0))
#define SDK_HAS_USERACTIVITY 1
#endif

/** Plist key that allows Firebase developers to disable App Delegate Proxying.  Source of truth is
 *  the GULAppDelegateSwizzler class.
 */
static NSString *const kGULFirebaseAppDelegateProxyEnabledPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

/** Plist key that allows non-Firebase developers to disable App Delegate Proxying.  Source of truth
 *  is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULGoogleAppDelegateProxyEnabledPlistKey =
    @"GoogleUtilitiesAppDelegateProxyEnabled";

#pragma mark - GULTestAppDelegate

/** This class conforms to the application delegate protocol and is there to be able to test the
 *  App Delegate Swizzler's behavior.
 */
@interface GULTestAppDelegate : NSObject <GULApplicationDelegate> {
 @public  // Because we want to access the ivars from outside the class like obj->ivar for testing.
  /** YES if the application:openURL:options: was called on an instance, NO otherwise. */
  BOOL _isOpenURLOptionsMethodCalled;

  /** Contains the backgroundSessionID that was passed to the
   *  application:handleEventsForBackgroundURLSession:completionHandler: method.
   */
  NSString *_backgroundSessionID;

  /** YES if init was called. Used for memory layout testing after isa swizzling. */
  BOOL _isInitialized;

  /** An arbitrary number. Used for memory layout testing after isa swizzling. */
  int _arbitraryNumber;
}

/** A URL property that is set by the app delegate methods, which is then used to verify if the app
 *  delegate methods were properly called.
 */
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSDictionary<NSString *, id> *openURLOptions;
@property(nonatomic, strong) NSString *openURLSourceApplication;

@property(nonatomic, strong) NSUserActivity *userActivity;

@property(nonatomic, strong) NSData *remoteNotificationsDeviceToken;
@property(nonatomic, strong) NSError *failToRegisterForRemoteNotificationsError;
@property(nonatomic, strong) NSDictionary *remoteNotification;

#if TARGET_OS_IOS || TARGET_OS_TV
@property(nonatomic, copy) void (^remoteNotificationCompletionHandler)(UIBackgroundFetchResult);
#endif  // TARGET_OS_IOS || TARGET_OS_TV

/**
 * The application is set each time a GULApplicationDelegate method is called
 */
@property(nonatomic, weak) GULApplication *application;

@end

@implementation GULTestAppDelegate

// TODO: The static BOOLs below being accurate is dependent on the runtime loading
// GULTestAppDelegate before GULAppDelegateSwizzlerTest. It works, but it might be a good idea to
// figure a way to make this more deterministic.

/** YES if GULTestAppDelegate responds to application:openURL:options:, NO otherwise. */
static BOOL gRespondsToOpenURLHandler_iOS9;

/** YES if GULTestAppDelegate responds to application:continueUserActivity:restorationHandler:, NO
 *  otherwise.
 */
static BOOL gRespondsToContinueUserActivity;

/** YES if GULTestAppDelegate responds to
 *  application:handleEventsForBackgroundURLSession:completionHandler:, NO otherwise.
 */
static BOOL gRespondsToHandleBackgroundSession;

+ (void)load {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

  gRespondsToOpenURLHandler_iOS9 =
      [self instancesRespondToSelector:@selector(application:openURL:options:)];
  gRespondsToHandleBackgroundSession =
      [self instancesRespondToSelector:
                @selector(application:handleEventsForBackgroundURLSession:completionHandler:)];
  gRespondsToContinueUserActivity = [self
      instancesRespondToSelector:@selector(application:continueUserActivity:restorationHandler:)];
#pragma clang diagnostic pop
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _isOpenURLOptionsMethodCalled = NO;
    _isInitialized = YES;
    _arbitraryNumber = 123456789;
    _backgroundSessionID = @"randomSessionID";
    _url = nil;
  }
  return self;
}

- (BOOL)application:(GULApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  self.application = app;
  self.url = url;
  self.openURLOptions = options;
  _isOpenURLOptionsMethodCalled = YES;
  return NO;
}

- (BOOL)application:(GULApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<GULUserActivityRestoring>> *__nullable
                                       restorableObjects))restorationHandler {
  self.application = application;
  self.userActivity = userActivity;
  return NO;
}

- (void)application:(GULApplication *)application
    handleEventsForBackgroundURLSession:(nonnull NSString *)identifier
                      completionHandler:(nonnull void (^)(void))completionHandler {
  self.application = application;
  _backgroundSessionID = identifier;
}

- (void)application:(GULApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  self.application = application;
  self.remoteNotificationsDeviceToken = deviceToken;
}

- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  self.application = application;
  self.failToRegisterForRemoteNotificationsError = error;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.application = application;
  self.remoteNotification = userInfo;
}
#pragma clang diagnostic pop

#if TARGET_OS_IOS || TARGET_OS_TV

- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.application = application;
  self.remoteNotification = userInfo;
  self.remoteNotificationCompletionHandler = completionHandler;
}

#endif  // TARGET_OS_IOS || TARGET_OS_TV

// These are methods to test whether changing the class still maintains behavior that the app
// delegate proxy shouldn't have modified.

- (NSString *)someArbitraryMethod {
  return @"blabla";
}

+ (int)someNumber {
  return 890;
}

@end

@interface GULEmptyTestAppDelegate : NSObject <GULApplicationDelegate>
@end

@implementation GULEmptyTestAppDelegate
@end

#pragma mark - Interceptor class

/** This is a class used to test whether interceptors work with the App Delegate Swizzler. */
@interface GULTestInterceptorAppDelegate : NSObject <GULApplicationDelegate>

/** URL sent to application:openURL:options:. */
@property(nonatomic, copy) NSURL *URLForIOS9;

/** The NSUserActivity sent to application:continueUserActivity:restorationHandler:. */
@property(nonatomic, copy) NSUserActivity *userActivity;

@end

@implementation GULTestInterceptorAppDelegate

- (BOOL)application:(GULApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  _URLForIOS9 = [url copy];
  return YES;
}

#if SDK_HAS_USERACTIVITY

- (BOOL)application:(GULApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *__nullable
                                       restorableObjects))restorationHandler {
  _userActivity = userActivity;
  return YES;
}

#endif  // SDK_HAS_USERACTIVITY

@end

@interface GULFakeApplication : NSObject
@property(nonatomic, strong) id<GULApplicationDelegate> delegate;
@end

@implementation GULFakeApplication
@end

static GULFakeApplication *gFakeApplication;

@interface GULApplication (FakeShared)
+ (GULApplication *)gul_fakeSharedApplication;
@end

@implementation GULApplication (FakeShared)
+ (GULApplication *)gul_fakeSharedApplication {
  return (GULApplication *)gFakeApplication;
}
@end

static NSDictionary *gAppFakeInfoDictionary;

@interface NSBundle (AppFakeInfoDictionary)
- (NSDictionary *)gul_app_fakeInfoDictionary;
@end
@implementation NSBundle (AppFakeInfoDictionary)
- (NSDictionary *)gul_app_fakeInfoDictionary {
  if (gAppFakeInfoDictionary) return gAppFakeInfoDictionary;
  return [self gul_app_fakeInfoDictionary];
}
@end

@interface GULFakeAppDelegateInterceptor : NSObject <GULApplicationDelegate>
@property(nonatomic) BOOL shouldReturnYES;
@property(nonatomic) BOOL isApplicationOpenURLOptionsCalled;
@property(nonatomic) BOOL isApplicationHandleEventsForBackgroundURLSessionCalled;
@property(nonatomic) BOOL isApplicationContinueUserActivityCalled;
@property(nonatomic) BOOL isApplicationDidRegisterForRemoteNotificationsCalled;
@property(nonatomic) BOOL isApplicationDidFailToRegisterForRemoteNotificationsCalled;
@property(nonatomic) BOOL isApplicationDidReceiveRemoteNotificationWithCompletionCalled;
@property(nonatomic, strong) dispatch_queue_t syncQueue;
#if (TARGET_OS_IOS || TARGET_OS_TV) && !TARGET_OS_MACCATALYST
@property(nonatomic, copy) void (^onDidReceiveRemoteNotificationWithCompletion)
    (NSDictionary *userInfo, void (^completionHandler)(UIBackgroundFetchResult));
#endif
@end

@implementation GULFakeAppDelegateInterceptor

- (instancetype)init {
  self = [super init];
  if (self) {
    _syncQueue = dispatch_queue_create("GULFakeAppDelegateInterceptor", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

#if TARGET_OS_IOS || TARGET_OS_TV
- (BOOL)application:(GULApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationOpenURLOptionsCalled = YES;
  });
  return self.shouldReturnYES;
}

- (void)application:(GULApplication *)application
    handleEventsForBackgroundURLSession:(nonnull NSString *)identifier
                      completionHandler:(nonnull void (^)(void))completionHandler {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationHandleEventsForBackgroundURLSessionCalled = YES;
  });
}
#endif

#if SDK_HAS_USERACTIVITY
- (BOOL)application:(GULApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<GULUserActivityRestoring>> *__nullable
                                       restorableObjects))restorationHandler {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationContinueUserActivityCalled = YES;
  });
  return self.shouldReturnYES;
}
#endif

- (void)application:(GULApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationDidRegisterForRemoteNotificationsCalled = YES;
  });
}

- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationDidFailToRegisterForRemoteNotificationsCalled = YES;
  });
}

#if (TARGET_OS_IOS || TARGET_OS_TV) && !TARGET_OS_MACCATALYST
- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  dispatch_sync(_syncQueue, ^{
    self->_isApplicationDidReceiveRemoteNotificationWithCompletionCalled = YES;
  });
  if (self.onDidReceiveRemoteNotificationWithCompletion) {
    self.onDidReceiveRemoteNotificationWithCompletion(userInfo, completionHandler);
  }
}
#endif

@end

@interface GULAppDelegateSwizzlerTest : XCTestCase
@end

@implementation GULAppDelegateSwizzlerTest

- (void)setUp {
  [super setUp];
  gFakeApplication = [[GULFakeApplication alloc] init];
  Method originalMethod =
      class_getClassMethod([GULApplication class], @selector(sharedApplication));
  Method swizzledMethod =
      class_getClassMethod([GULApplication class], @selector(gul_fakeSharedApplication));
  method_exchangeImplementations(originalMethod, swizzledMethod);

  Method originalBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
  Method swizzledBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(gul_app_fakeInfoDictionary));
  method_exchangeImplementations(originalBundleMethod, swizzledBundleMethod);
}

- (void)tearDown {
  [GULAppDelegateSwizzler clearInterceptors];
  [GULAppDelegateSwizzler resetProxyOriginalDelegateOnceToken];
  Method originalMethod =
      class_getClassMethod([GULApplication class], @selector(sharedApplication));
  Method swizzledMethod =
      class_getClassMethod([GULApplication class], @selector(gul_fakeSharedApplication));
  method_exchangeImplementations(originalMethod, swizzledMethod);
  gFakeApplication = nil;

  Method originalBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
  Method swizzledBundleMethod =
      class_getInstanceMethod([NSBundle class], @selector(gul_app_fakeInfoDictionary));
  method_exchangeImplementations(originalBundleMethod, swizzledBundleMethod);
  gAppFakeInfoDictionary = nil;

  [super tearDown];
}

- (void)testNotAppDelegateIsNotSwizzled {
  NSObject *notAppDelegate = [[NSObject alloc] init];
  [GULApplication sharedApplication].delegate = (id<GULApplicationDelegate>)notAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];
  XCTAssertEqualObjects(NSStringFromClass([notAppDelegate class]), @"NSObject");
}

/** Tests proxying an object that responds to application delegate protocol and makes sure that
 *  it is isa swizzled and that the object after proxying responds to the expected methods
 *  and doesn't have its ivars modified.
 */
- (void)testProxyAppDelegate {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;
  size_t sizeBefore = class_getInstanceSize([GULTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
  XCTAssertTrue(
      [realAppDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]);
#if TARGET_OS_IOS || TARGET_OS_TV
  XCTAssertTrue([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:handleEventsForBackgroundURLSession:completionHandler:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
#endif  // TARGET_OS_IOS || TARGET_OS_TV

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);

  // Make sure that the ivars are not changed in memory as the subclass is created. Directly
  // accessing the ivars should not crash.
  XCTAssertEqual(realAppDelegate->_arbitraryNumber, 123456789);
  XCTAssertEqual(realAppDelegate->_isInitialized, 1);
  XCTAssertFalse(realAppDelegate->_isOpenURLOptionsMethodCalled);
  XCTAssertEqualObjects(realAppDelegate->_backgroundSessionID, @"randomSessionID");
}

- (void)testProxyEmptyAppDelegate {
  GULEmptyTestAppDelegate *realAppDelegate = [[GULEmptyTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;
  size_t sizeBefore = class_getInstanceSize([GULEmptyTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULEmptyTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULEmptyTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)]);
  // Remote notifications methods should be added only by
  // -proxyOriginalDelegateIncludingAPNSMethods
  XCTAssertFalse([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertFalse([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);
  XCTAssertFalse(
      [realAppDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)]);
#if TARGET_OS_IOS || TARGET_OS_TV
  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:handleEventsForBackgroundURLSession:completionHandler:)]);
  XCTAssertFalse([realAppDelegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
#endif  // TARGET_OS_IOS || TARGET_OS_TV

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);
}

- (void)testProxyRemoteNotificationsMethodsEmptyAppDelegate {
  GULEmptyTestAppDelegate *realAppDelegate = [[GULEmptyTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;
  size_t sizeBefore = class_getInstanceSize([GULEmptyTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULEmptyTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULEmptyTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)]);

  // Remote notifications methods should be added only by
  // -proxyOriginalDelegateIncludingAPNSMethods
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:handleEventsForBackgroundURLSession:completionHandler:)]);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);
}

- (void)testProxyRemoteNotificationsMethodsEmptyAppDelegateAfterInitialProxy {
  GULEmptyTestAppDelegate *realAppDelegate = [[GULEmptyTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;
  size_t sizeBefore = class_getInstanceSize([GULEmptyTestAppDelegate class]);

  Class realAppDelegateClassBefore = [realAppDelegate class];

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  XCTAssertTrue([realAppDelegate isKindOfClass:[GULEmptyTestAppDelegate class]]);

  NSString *newClassName = NSStringFromClass([realAppDelegate class]);
  XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
  // It is no longer GULTestAppDelegate class instance.
  XCTAssertFalse([realAppDelegate isMemberOfClass:[GULEmptyTestAppDelegate class]]);

  size_t sizeAfter = class_getInstanceSize([realAppDelegate class]);

  // Class size must stay the same.
  XCTAssertEqual(sizeBefore, sizeAfter);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)]);
  // Proxy remote notifications methods
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)]);

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
  // The implementation should not be added if there is no original implementation
  XCTAssertFalse([realAppDelegate respondsToSelector:@selector(application:openURL:options:)]);
  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:handleEventsForBackgroundURLSession:completionHandler:)]);

  XCTAssertTrue([realAppDelegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

  // Make sure that the class has changed.
  XCTAssertNotEqualObjects([realAppDelegate class], realAppDelegateClassBefore);
}

#if SDK_HAS_USERACTIVITY
- (void)testHandleBackgroundSessionMethod {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  GULApplication *currentApplication = [GULApplication sharedApplication];
  NSString *sessionID = @"123";
  void (^nilHandler)(void) = nil;
  [realAppDelegate application:currentApplication
      handleEventsForBackgroundURLSession:sessionID
                        completionHandler:nilHandler];

  // Intentionally access the ivars directly. It should be set to the session ID as the real method
  // is called.
  XCTAssertEqualObjects(realAppDelegate->_backgroundSessionID, sessionID);
}
#endif  // SDK_HAS_USERACTIVITY

/** Tests registering and unregistering invalid interceptors. */
- (void)testInvalidInterceptor {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows([GULAppDelegateSwizzler registerAppDelegateInterceptor:nil],
                  @"Should not register nil interceptor");
#pragma clang diagnostic pop
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 0);

  // Try to register some random object that does not conform to application delegate.
  NSObject *randomObject = [[NSObject alloc] init];

  XCTAssertThrows([GULAppDelegateSwizzler
                      registerAppDelegateInterceptor:(id<GULApplicationDelegate>)randomObject],
                  @"Should not register interceptor that does not conform to %@Delegate",
                  kGULApplicationClassName);
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 0);

  GULTestInterceptorAppDelegate *interceptorAppDelegate =
      [[GULTestInterceptorAppDelegate alloc] init];
  GULAppDelegateInterceptorID interceptorID =
      [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptorAppDelegate];
  XCTAssertNotNil(interceptorID);
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 1);

  // Register the same object. Should not change the number of objects.
  XCTAssertNotNil([GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptorAppDelegate]);
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 1);

  XCTAssertThrows([GULAppDelegateSwizzler unregisterAppDelegateInterceptorWithID:@""],
                  @"Should not unregister empty interceptor ID");
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 1);

  // Try to unregister an empty string. Should not remove anything.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows([GULAppDelegateSwizzler unregisterAppDelegateInterceptorWithID:nil],
                  @"Should not unregister nil interceptorID");
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 1);

  // Try to unregister a random string. Should not remove anything.
  [GULAppDelegateSwizzler unregisterAppDelegateInterceptorWithID:@"random ID"];
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 1);

  // Unregister the right one.
  [GULAppDelegateSwizzler unregisterAppDelegateInterceptorWithID:interceptorID];
  XCTAssertEqual([GULAppDelegateSwizzler interceptors].count, 0);
}

/** Tests that the description of appDelegate object doesn't change even after proxying it. */
- (void)testDescription {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;
  Class classBefore = [realAppDelegate class];
  NSString *descriptionBefore = [realAppDelegate description];

  [GULAppDelegateSwizzler proxyOriginalDelegate];

  Class classAfter = [realAppDelegate class];
  NSString *descriptionAfter = [realAppDelegate description];

  NSString *descriptionString =
      [NSString stringWithFormat:@"<GULTestAppDelegate: %p>", realAppDelegate];

  // The description must be the same even though the class has changed.
  XCTAssertEqualObjects(descriptionBefore, descriptionAfter);
  XCTAssertNotEqualObjects(classAfter, classBefore);
  XCTAssertEqualObjects(descriptionAfter, descriptionString);
}

/** Tests that methods that are not overridden by the App Delegate Proxy still work as expected. */
- (void)testNotOverriddenMethods {
  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = realAppDelegate;

  // Create the proxy.
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  // Make sure that original class instance method still works.
  XCTAssertEqualObjects([realAppDelegate someArbitraryMethod], @"blabla");

  // Make sure that the new subclass inherits the original class method.
  XCTAssertEqual([[realAppDelegate class] someNumber], 890);

  // Make sure that the original class still works.
  XCTAssertEqual([GULTestAppDelegate someNumber], 890);
}

#if !SWIFT_PACKAGE
// TODO: Investigate why this test fails in Swift PM builds.

/** Tests that if the app delegate changes after it has been proxied, the App Delegate Swizzler
 *  handles it correctly.
 */
- (void)testAppDelegateInstance {
  // The test logic involves using KVC on the UIApplication.delegate property. This does not really
  // work well with OCMPartialMock([GULApplication sharedApplication]) and triggers issue
  // https://github.com/erikdoe/ocmock/issues/346.
  // Let's stop mocking the shared application for this particular test.

  GULTestAppDelegate *realAppDelegate = [[GULTestAppDelegate alloc] init];

  [GULApplication sharedApplication].delegate = realAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  XCTAssertEqualObjects([GULAppDelegateSwizzler originalDelegate], realAppDelegate);

  GULTestInterceptorAppDelegate *anotherAppDelegate = [[GULTestInterceptorAppDelegate alloc] init];
  XCTAssertNotEqualObjects(realAppDelegate, anotherAppDelegate);

  [GULApplication sharedApplication].delegate = anotherAppDelegate;
  // Make sure that the new delegate is swizzled out and set correctly.
  XCTAssertNil([GULAppDelegateSwizzler originalDelegate]);

  [GULAppDelegateSwizzler proxyOriginalDelegate];

  // Swizzling of an updated app delegate is not supported so far.
  XCTAssertNil([GULAppDelegateSwizzler originalDelegate]);
}
#endif

#pragma mark - Tests the behaviour with interceptors

#if TARGET_OS_IOS || TARGET_OS_TV
/** Tests that application:openURL:options: is invoked on the interceptor if it exists. */
- (void)testApplicationOpenURLOptionsIsInvokedOnInterceptors {
  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  NSURL *testURL = [[NSURL alloc] initWithString:@"https://www.google.com"];
  NSDictionary *testOpenURLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @"test"};

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;

  [GULAppDelegateSwizzler proxyOriginalDelegate];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:[GULApplication sharedApplication]
                       openURL:testURL
                       options:testOpenURLOptions];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationOpenURLOptionsCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationOpenURLOptionsCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  // Check that original implementation was called with proper parameters
  XCTAssertEqual(testAppDelegate.application, [GULApplication sharedApplication]);
  XCTAssertEqual(testAppDelegate.url, testURL);
}

/** Tests that the result of application:openURL:options: from all interceptors is ORed. */
- (void)testResultOfApplicationOpenURLOptionsIsORed {
  NSURL *testURL = [[NSURL alloc] initWithString:@"https://www.google.com"];
  NSDictionary *testOpenURLOptions = @{UIApplicationOpenURLOptionUniversalLinksOnly : @"test"};

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  BOOL shouldOpen = [testAppDelegate application:[GULApplication sharedApplication]
                                         openURL:testURL
                                         options:testOpenURLOptions];
  // Verify that the original app delegate returns NO.
  XCTAssertFalse(shouldOpen);

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor.shouldReturnYES = NO;
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  shouldOpen = [testAppDelegate application:[GULApplication sharedApplication]
                                    openURL:testURL
                                    options:testOpenURLOptions];
  // Verify that if the only interceptor returns NO, the value is still NO.
  XCTAssertFalse(shouldOpen);

  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor2.shouldReturnYES = YES;
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  shouldOpen = [testAppDelegate application:[GULApplication sharedApplication]
                                    openURL:testURL
                                    options:testOpenURLOptions];
  // Verify that if one of the two interceptors returns YES, the value is YES.
  XCTAssertTrue(shouldOpen);
}
#endif  // TARGET_OS_IOS || TARGET_OS_TV

#if TARGET_OS_IOS || TARGET_OS_TV
/** Tests that application:handleEventsForBackgroundURLSession:completionHandler: is invoked on the
 *  interceptors if it exists.
 */
- (void)testApplicationHandleEventsForBackgroundURLSessionIsInvokedOnInterceptors {
  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  NSString *backgroundSessionID = @"testBackgroundSessionID";
  [testAppDelegate application:[GULApplication sharedApplication]
      handleEventsForBackgroundURLSession:backgroundSessionID
                        completionHandler:^{
                        }];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationHandleEventsForBackgroundURLSessionCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationHandleEventsForBackgroundURLSessionCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  // Check that original implementation was called with proper parameters
  XCTAssertEqual(testAppDelegate.application, [GULApplication sharedApplication]);
  XCTAssertEqual(testAppDelegate->_backgroundSessionID, backgroundSessionID);
}
#endif  // TARGET_OS_IOS || TARGET_OS_TV

#if SDK_HAS_USERACTIVITY
/** Tests that application:continueUserActivity:restorationHandler: is invoked on the interceptors
 *  if it exists.
 */
- (void)testApplicationContinueUserActivityRestorationHandlerIsInvokedOnInterceptors {
  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  NSUserActivity *testUserActivity = [[NSUserActivity alloc] initWithActivityType:@"test"];

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:[GULApplication sharedApplication]
          continueUserActivity:testUserActivity
            restorationHandler:^(NSArray *restorableObjects){
            }];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationContinueUserActivityCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationContinueUserActivityCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  // Check that original implementation was called with proper parameters
  XCTAssertEqual(testAppDelegate.application, [GULApplication sharedApplication]);
  XCTAssertEqual(testAppDelegate.userActivity, testUserActivity);
}

/** Tests that the results of application:continueUserActivity:restorationHandler: from the
 *  interceptors are ORed.
 */
- (void)testApplicationContinueUserActivityRestorationHandlerResultsAreORed {
  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegate];
  NSUserActivity *testUserActivity = [[NSUserActivity alloc] initWithActivityType:@"test"];

  BOOL shouldContinueUserActivity = [testAppDelegate application:[GULApplication sharedApplication]
                                            continueUserActivity:testUserActivity
                                              restorationHandler:^(NSArray *restorableObjects){
                                              }];
  // Verify that it is NO when there are no interceptors.
  XCTAssertFalse(shouldContinueUserActivity);

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor.shouldReturnYES = NO;
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  shouldContinueUserActivity = [testAppDelegate application:[GULApplication sharedApplication]
                                       continueUserActivity:testUserActivity
                                         restorationHandler:^(NSArray *restorableObjects){
                                         }];
  // Verify that it is NO when the only interceptor returns a NO.
  XCTAssertFalse(shouldContinueUserActivity);

  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor2.shouldReturnYES = YES;
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  shouldContinueUserActivity = [testAppDelegate application:[GULApplication sharedApplication]
                                       continueUserActivity:testUserActivity
                                         restorationHandler:^(NSArray *restorableObjects){
                                         }];
  // Verify that if one of the two interceptors returns YES, the value is YES.
  XCTAssertTrue(shouldContinueUserActivity);
}
#endif  // SDK_HAS_USERACTIVITY

- (void)testApplicationDidRegisterForRemoteNotificationsIsInvokedOnInterceptors {
  NSData *deviceToken = [NSData data];
  GULApplication *application = [GULApplication sharedApplication];

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationDidRegisterForRemoteNotificationsCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationDidRegisterForRemoteNotificationsCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.remoteNotificationsDeviceToken, deviceToken);
}

- (void)testApplicationDidFailToRegisterForRemoteNotificationsIsInvokedOnInterceptors {
  NSError *error = [NSError errorWithDomain:@"test" code:-1 userInfo:nil];
  GULApplication *application = [GULApplication sharedApplication];

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application didFailToRegisterForRemoteNotificationsWithError:error];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationDidFailToRegisterForRemoteNotificationsCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationDidFailToRegisterForRemoteNotificationsCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.failToRegisterForRemoteNotificationsError, error);
}

#if (TARGET_OS_IOS || TARGET_OS_TV) && !TARGET_OS_MACCATALYST
- (void)testApplicationDidReceiveRemoteNotificationWithCompletionIsInvokedOnInterceptors {
  NSDictionary *notification = @{};
  GULApplication *application = [GULApplication sharedApplication];
  void (^completion)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {
  };

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application
      didReceiveRemoteNotification:notification
            fetchCompletionHandler:completion];

  __block BOOL isCalled1 = NO;
  __block BOOL isCalled2 = NO;
  dispatch_sync(interceptor.syncQueue, ^{
    isCalled1 = interceptor.isApplicationDidReceiveRemoteNotificationWithCompletionCalled;
  });
  dispatch_sync(interceptor2.syncQueue, ^{
    isCalled2 = interceptor2.isApplicationDidReceiveRemoteNotificationWithCompletionCalled;
  });

  XCTAssertTrue(isCalled1);
  XCTAssertTrue(isCalled2);

  XCTAssertEqual(testAppDelegate.application, application);
  XCTAssertEqual(testAppDelegate.remoteNotification, notification);
}

- (void)verifyCompletionCalledForObserverResult:(UIBackgroundFetchResult)observerResult1
                          anotherObserverResult:(UIBackgroundFetchResult)observerResult2
                                 swizzledResult:(UIBackgroundFetchResult)swizzledResult
                                 expectedResult:(UIBackgroundFetchResult)expectedResult {
  NSDictionary *notification = @{};
  GULApplication *application = [GULApplication sharedApplication];

  XCTestExpectation *completionExpectation =
      [[XCTestExpectation alloc] initWithDescription:@"Completion called once"];

  void (^completion)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {
    XCTAssertEqual(result, expectedResult);
    [completionExpectation fulfill];
  };

  GULFakeAppDelegateInterceptor *interceptor = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor.onDidReceiveRemoteNotificationWithCompletion =
      ^(NSDictionary *userInfo, void (^completionHandler)(UIBackgroundFetchResult)) {
        completionHandler(observerResult1);
      };

  GULFakeAppDelegateInterceptor *interceptor2 = [[GULFakeAppDelegateInterceptor alloc] init];
  interceptor2.onDidReceiveRemoteNotificationWithCompletion =
      ^(NSDictionary *userInfo, void (^completionHandler)(UIBackgroundFetchResult)) {
        completionHandler(observerResult2);
      };

  GULTestAppDelegate *testAppDelegate = [[GULTestAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = testAppDelegate;
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor2];

  [testAppDelegate application:application
      didReceiveRemoteNotification:notification
            fetchCompletionHandler:completion];
  testAppDelegate.remoteNotificationCompletionHandler(swizzledResult);
  [self waitForExpectations:@[ completionExpectation ] timeout:0.1];
}

- (void)testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultNoData
                          anotherObserverResult:UIBackgroundFetchResultNoData
                                 swizzledResult:UIBackgroundFetchResultNoData
                                 expectedResult:UIBackgroundFetchResultNoData];
}

- (void)
    testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce_HandleFailedState {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultFailed
                          anotherObserverResult:UIBackgroundFetchResultFailed
                                 swizzledResult:UIBackgroundFetchResultFailed
                                 expectedResult:UIBackgroundFetchResultFailed];
}

- (void)testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce_NoData {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultNoData
                          anotherObserverResult:UIBackgroundFetchResultFailed
                                 swizzledResult:UIBackgroundFetchResultFailed
                                 expectedResult:UIBackgroundFetchResultNoData];
}
- (void)
    testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce_HandleNewDataState_OthersFailed {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultNewData
                          anotherObserverResult:UIBackgroundFetchResultFailed
                                 swizzledResult:UIBackgroundFetchResultFailed
                                 expectedResult:UIBackgroundFetchResultNewData];
}

- (void)
    testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce_HandleNewDataState_OthersNoData {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultNewData
                          anotherObserverResult:UIBackgroundFetchResultNoData
                                 swizzledResult:UIBackgroundFetchResultNoData
                                 expectedResult:UIBackgroundFetchResultNewData];
}

- (void)
    testApplicationDidReceiveRemoteNotificationWithCompletionCompletionIsCalledOnce_HandleNewDataState_OthersNoDataFailed {
  [self verifyCompletionCalledForObserverResult:UIBackgroundFetchResultNewData
                          anotherObserverResult:UIBackgroundFetchResultNoData
                                 swizzledResult:UIBackgroundFetchResultFailed
                                 expectedResult:UIBackgroundFetchResultNewData];
}

- (void)testApplicationDidReceiveRemoteNotificationWithCompletionImplementationIsAdded {
  // The delegate must have an application:didReceiveRemoteNotification:fetchCompletionHandler:
  // implementation
  GULTestInterceptorAppDelegate *delegate = [[GULTestInterceptorAppDelegate alloc] init];
  [GULApplication sharedApplication].delegate = delegate;

  XCTAssertFalse([delegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);

  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];

  XCTAssertTrue([delegate
      respondsToSelector:@selector(
                             application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
}
#endif  // TARGET_OS_IOS || TARGET_OS_TV

#pragma mark - Tests to test that Plist flag is honored

/** Tests that app delegate proxy is enabled when there is no Info.plist dictionary. */
- (void)testAppProxyPlistFlag_NoFlag {
  gAppFakeInfoDictionary = nil;
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlistFlag_NoAppDelegateProxyKey {
  gAppFakeInfoDictionary = @{@"randomKey" : @"randomValue"};
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlistFlag_FirebaseEnabled {
  gAppFakeInfoDictionary = @{kGULFirebaseAppDelegateProxyEnabledPlistKey : @(YES)};
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlistFlag_GoogleEnabled {
  gAppFakeInfoDictionary = @{kGULGoogleAppDelegateProxyEnabledPlistKey : @(YES)};
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_WrongFirebaseDisableFlagValueType {
  gAppFakeInfoDictionary = @{kGULFirebaseAppDelegateProxyEnabledPlistKey : @"NO"};
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_WrongGoogleDisableFlagValueType {
  gAppFakeInfoDictionary = @{kGULGoogleAppDelegateProxyEnabledPlistKey : @"NO"};
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_FirebaseDisableFlag {
  gAppFakeInfoDictionary = @{kGULFirebaseAppDelegateProxyEnabledPlistKey : @(NO)};
  NSLog(@"gAppFakeInfoDictionary: %@", gAppFakeInfoDictionary);
  NSLog(@"mainBundle: %@", [NSBundle mainBundle]);
  NSLog(@"infoDictionary: %@", [NSBundle mainBundle].infoDictionary);
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_GoogleDisableFlag {
  gAppFakeInfoDictionary = @{kGULGoogleAppDelegateProxyEnabledPlistKey : @(NO)};
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_GoogleDisableFlagFirebaseEnableFlag {
  gAppFakeInfoDictionary = @{
    kGULGoogleAppDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseAppDelegateProxyEnabledPlistKey : @(YES)
  };
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_FirebaseDisableFlagGoogleEnableFlag {
  gAppFakeInfoDictionary = @{
    kGULGoogleAppDelegateProxyEnabledPlistKey : @(YES),
    kGULFirebaseAppDelegateProxyEnabledPlistKey : @(NO)
  };
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppProxyPlist_FirebaseDisableFlagGoogleDisableFlag {
  gAppFakeInfoDictionary = @{
    kGULGoogleAppDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseAppDelegateProxyEnabledPlistKey : @(NO)
  };
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);
}

- (void)testAppDelegateIsNotProxiedWhenDisabled {
  gAppFakeInfoDictionary = @{kGULFirebaseAppDelegateProxyEnabledPlistKey : @(NO)};
  XCTAssertFalse([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);

  id originalAppDelegate = [[GULTestAppDelegate alloc] init];
  Class originalAppDelegateClass = [originalAppDelegate class];
  XCTAssertNotNil(originalAppDelegate);
  [GULApplication sharedApplication].delegate = originalAppDelegate;

  [GULAppDelegateSwizzler proxyOriginalDelegate];
  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];
  XCTAssertEqualObjects([originalAppDelegate class], originalAppDelegateClass);
}

- (void)testAppDelegateIsProxiedWhenEnabled {
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);

  id originalAppDelegate = [[GULTestAppDelegate alloc] init];
  Class originalAppDelegateClass = [originalAppDelegate class];
  XCTAssertNotNil(originalAppDelegate);
  [GULApplication sharedApplication].delegate = originalAppDelegate;

  [GULAppDelegateSwizzler proxyOriginalDelegate];
  XCTAssertNotEqualObjects([originalAppDelegate class], originalAppDelegateClass);
}

- (void)testAppDelegateIsProxiedIncludingAPNSMethodsWhenEnabled {
  XCTAssertTrue([GULAppDelegateSwizzler isAppDelegateProxyEnabled]);

  id originalAppDelegate = [[GULTestAppDelegate alloc] init];
  Class originalAppDelegateClass = [originalAppDelegate class];
  XCTAssertNotNil(originalAppDelegate);
  [GULApplication sharedApplication].delegate = originalAppDelegate;

  [GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods];
  XCTAssertNotEqualObjects([originalAppDelegate class], originalAppDelegateClass);
}

@end
