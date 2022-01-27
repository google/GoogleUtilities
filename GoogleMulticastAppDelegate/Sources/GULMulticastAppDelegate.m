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

#import "GoogleMulticastAppDelegate/Sources/Public/GoogleUtilities/GULMulticastAppDelegate.h"



@interface GULMulticastAppDelegate ()<GULMulticastAppDelegateProtocol> {
  NSMutableArray<id>* _interceptors;
}
@end

@implementation GULMulticastAppDelegate

- (instancetype)init {
  self = [super init];
  if (self) {
    _interceptors = [[NSMutableArray alloc] init];
  }
  return self;
}

+ (id<GULMulticastAppDelegateProtocol>)multicastDelegate {
  
  id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
  if (appDelegate && [appDelegate respondsToSelector:@selector(getMulticastDelegate)]) {
    
    id<GULMulticastAppDelegateProtocol> multicastDelegate = [appDelegate performSelector:@selector(getMulticastDelegate)];
    CFRetain((__bridge CFTypeRef)(multicastDelegate));
    return multicastDelegate;
  }
  return nil;
}


- (id<GULMulticastAppDelegateProtocol>)getMulticastDelegate {
  return self;
}


-(void)addInterceptorWithDelegate:(id<GULApplicationDelegate>)interceptor {
  [_interceptors addObject:interceptor];
}

-(void)removeInterceptorWithDelegate:(id<GULApplicationDelegate>)interceptor {
  [_interceptors removeObject:interceptor];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if ([[self class] instancesRespondToSelector:aSelector]) {
    return YES;
  }
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if (interceptor && [interceptor respondsToSelector:aSelector]) {
      return YES;
    }
  }
  return NO;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    if (interceptor && [interceptor respondsToSelector:aSelector]) {
      return interceptor;
    }
  }
  return nil;
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
    [interceptor application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
  }
}

#else // !TARGET_OS_WATCH
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    [interceptor didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
  }
}
#endif // !TARGET_OS_WATCH

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    [interceptor application:application didFailToRegisterForRemoteNotificationsWithError:error];
  }
}

- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  for (id<GULApplicationDelegate> interceptor in _interceptors) {
    [interceptor application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
  }
}
#endif

@end
