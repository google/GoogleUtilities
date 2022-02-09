// Copyright 2022 Google LLC
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

#import <GoogleUtilitiesMulticastAppDelegate/GULMulticastUserNotificationCenterDelegate.h>

API_AVAILABLE(ios(10.0))
@interface GULMulticastUserNotificationCenterDelegate () <GULMulticastAppDelegateProtocol> {
  NSMutableArray<id> *_interceptors;
  id<GULApplicationDelegate,UNUserNotificationCenterDelegate> _defaultAppDelegate;
}
@end

@implementation GULMulticastUserNotificationCenterDelegate

- (instancetype)initWithAppDelegate:(id<GULApplicationDelegate,UNUserNotificationCenterDelegate>)delegate  API_AVAILABLE(ios(10.0)){
  self = [super init];
  if (self) {
    _interceptors = [NSMutableArray arrayWithObject:delegate];
    [UNUserNotificationCenter currentNotificationCenter].delegate = delegate;
    _defaultAppDelegate = delegate;
  }
  return self;
}

+ (id<GULMulticastAppDelegateProtocol>)multicastDelegate {
  if (@available(iOS 10.0, *)) {
    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;

    if (!appDelegate) {
      return nil;
    }
    if ([appDelegate conformsToProtocol:@protocol(GULMulticastAppDelegateProtocol)]) {
      id<GULMulticastAppDelegateProtocol> multicastAppDelegate =
      (id<GULMulticastAppDelegateProtocol>)appDelegate;
      return multicastAppDelegate;
    }
    if ([appDelegate respondsToSelector:@selector(getMulticastDelegate)]) {
      id<GULMulticastAppDelegateProtocol> multicastDelegate =
      [appDelegate performSelector:@selector(getMulticastDelegate)];
      CFRetain((__bridge CFTypeRef)(multicastDelegate));
      return multicastDelegate;
    }
  } else {
    // Fallback on earlier versions
  }
  return nil;
}

- (id<GULMulticastAppDelegateProtocol>)getMulticastDelegate {
  return self;
}

- (void)addInterceptorWithInterceptor:(id<GULApplicationDelegate,UNUserNotificationCenterDelegate>)interceptor  API_AVAILABLE(ios(10.0)){
  [_interceptors addObject:interceptor];
}

- (void)removeInterceptorWithInterceptor:(id<GULApplicationDelegate,UNUserNotificationCenterDelegate>)interceptor  API_AVAILABLE(ios(10.0)){
  [_interceptors removeObject:interceptor];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if ([[self class] instancesRespondToSelector:aSelector]) {
    return YES;
  }
  for (id<GULApplicationDelegate, UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if (interceptor && [interceptor respondsToSelector:aSelector]) {
      return YES;
    }
  }
  return NO;
}

- (void)setDefaultAppDelegate:(id<GULApplicationDelegate,UNUserNotificationCenterDelegate>)defaultAppDelegate  API_AVAILABLE(ios(10.0)){
  [_interceptors addObject:defaultAppDelegate];
  _defaultAppDelegate = defaultAppDelegate;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  return _defaultAppDelegate;
}

#if !TARGET_OS_WATCH
#pragma mark - Open URL
- (BOOL)application:(GULApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  BOOL result = NO;
  for (id<UIApplicationDelegate> interceptor in _interceptors) {
    result = result || [interceptor application:app openURL:url options:options];
  }
  return result;
}

#pragma mark - APNS methods
- (void)application:(GULApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector(application:
                                            didRegisterForRemoteNotificationsWithDeviceToken:)]) {
      [interceptor application:application
          didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
  }
}

#else   // !TARGET_OS_WATCH
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if ([interceptor
            respondsToSelector:@selector(didRegisterForRemoteNotificationsWithDeviceToken)]) {
      [interceptor didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
  }
}
#endif  // !TARGET_OS_WATCH

#if TARGET_OS_WATCH

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector(didFailToRegisterForRemoteNotificationsWithError:)]) {
      [interceptor didFailToRegisterForRemoteNotificationsWithError:error];
    }
  }
}
#elif TARGET_OS_IOS || TARGET_OS_TV
- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector(application:
                                            didFailToRegisterForRemoteNotificationsWithError:)]) {
      [interceptor application:application didFailToRegisterForRemoteNotificationsWithError:error];
    }
  }
}

- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector
                     (application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
      [interceptor application:application
          didReceiveRemoteNotification:userInfo
                fetchCompletionHandler:completionHandler];
    }
  }
}
#endif

#pragma mark - UNUserNotificationCenterDelegate

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler  API_AVAILABLE(ios(10.0)){
  for (id<UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector
                     (userNotificationCenter:willPresentNotification:withCompletionHandler:)]) {
      [interceptor userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
    }
  }
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler  API_AVAILABLE(ios(10.0)){
  for (id<UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector
                     (userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
      [interceptor userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
    }
  }
}

@end
