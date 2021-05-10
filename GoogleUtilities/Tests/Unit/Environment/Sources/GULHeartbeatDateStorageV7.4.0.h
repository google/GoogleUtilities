/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// MARK: This file is strictly for version compatibility testing.

#import <Foundation/Foundation.h>

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULHeartbeatDateStorable.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kGULHeartbeatStorageDirectory7_4_0;  // Avoids duplicate linker error.

/// Stores either a date or a dictionary to a specified file.
@interface GULHeartbeatDateStorage7_4_0 : NSObject <GULHeartbeatDateStorable>

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, readonly) NSURL *fileURL;

/**
 * Default initializer.
 * @param fileName The name of the file to store the date information.
 * exist, it will be created if needed.
 */
- (instancetype)initWithFileName:(NSString *)fileName;

/**
 * Reads the date from the specified file for the given tag.
 * @return Returns date if exists, otherwise `nil`.
 */
- (nullable NSDate *)heartbeatDateForTag:(NSString *)tag;

/**
 * Saves the date for the specified tag in the specified file.
 * @return YES on success, NO otherwise.
 */
- (BOOL)setHearbeatDate:(NSDate *)date forTag:(NSString *)tag;

@end

NS_ASSUME_NONNULL_END
