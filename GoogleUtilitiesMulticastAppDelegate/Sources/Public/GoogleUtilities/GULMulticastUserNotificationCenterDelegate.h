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

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0 ||                                          \
    __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_14 || __TV_OS_VERSION_MAX_ALLOWED >= __TV_10_0 || \
    __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_3_0 || TARGET_OS_MACCATALYST
#import <UserNotifications/UserNotifications.h>
#endif
#import <GoogleUtilitiesMulticastAppDelegate/GULMulticastAppDelegate.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(10.0))
@interface GULMulticastUserNotificationCenterDelegate : NSObject <GULApplicationDelegate, UNUserNotificationCenterDelegate>

@property(nonatomic, copy) id<GULApplicationDelegate, UNUserNotificationCenterDelegate> defaultAppDelegate;

-(instancetype)initWithAppDelegate:(id<GULApplicationDelegate, UNUserNotificationCenterDelegate>)delegate;

-(void)addInterceptorWithInterceptor:(id<GULApplicationDelegate, UNUserNotificationCenterDelegate>)delegate;

+ (id<GULMulticastAppDelegateProtocol>)multicastDelegate;
@end

NS_ASSUME_NONNULL_END
