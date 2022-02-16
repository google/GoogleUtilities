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
  id<UNUserNotificationCenterDelegate> _defaultAppDelegate;
}
@end

@implementation GULMulticastUserNotificationCenterDelegate

- (instancetype)init API_AVAILABLE(ios(10.0)) {
  self = [super init];
  if (self) {
    _interceptors = [NSMutableArray array];
  }
  return self;
}

+ (id<GULMulticastNotificationProtocol>)multicastDelegate {
  if (@available(iOS 10.0, *)) {
    id<UNUserNotificationCenterDelegate> appDelegate =
        [UNUserNotificationCenter currentNotificationCenter].delegate;

    if (!appDelegate) {
      return nil;
    }
    if ([appDelegate conformsToProtocol:@protocol(GULMulticastNotificationProtocol)]) {
      id<GULMulticastNotificationProtocol> multicastAppDelegate =
          (id<GULMulticastNotificationProtocol>)appDelegate;
      return multicastAppDelegate;
    }
    if ([appDelegate respondsToSelector:@selector(getMulticastDelegate)]) {
      id<GULMulticastNotificationProtocol> multicastDelegate =
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

- (void)addInterceptorWithInterceptor:(id<UNUserNotificationCenterDelegate>)interceptor
    API_AVAILABLE(ios(10.0)) {
  [_interceptors addObject:interceptor];
}

- (void)removeInterceptorWithInterceptor:(id<UNUserNotificationCenterDelegate>)interceptor
    API_AVAILABLE(ios(10.0)) {
  [_interceptors removeObject:interceptor];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if ([[self class] instancesRespondToSelector:aSelector]) {
    return YES;
  }
  for (id<UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if (interceptor && [interceptor respondsToSelector:aSelector]) {
      return YES;
    }
  }
  return NO;
}

- (void)setDefaultAppDelegate:(id<UNUserNotificationCenterDelegate>)defaultAppDelegate
    API_AVAILABLE(ios(10.0)) {
  [_interceptors addObject:defaultAppDelegate];
  _defaultAppDelegate = defaultAppDelegate;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  return _defaultAppDelegate;
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
    API_AVAILABLE(ios(10.0)) {
  for (id<UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if ([interceptor respondsToSelector:@selector(userNotificationCenter:
                                                 willPresentNotification:withCompletionHandler:)]) {
      [interceptor userNotificationCenter:center
                  willPresentNotification:notification
                    withCompletionHandler:completionHandler];
    }
  }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0)) {
  for (id<UNUserNotificationCenterDelegate> interceptor in _interceptors) {
    if ([interceptor
            respondsToSelector:@selector(userNotificationCenter:
                                   didReceiveNotificationResponse:withCompletionHandler:)]) {
      [interceptor userNotificationCenter:center
           didReceiveNotificationResponse:response
                    withCompletionHandler:completionHandler];
    }
  }
}

@end
