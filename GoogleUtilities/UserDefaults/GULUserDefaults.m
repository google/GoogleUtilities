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

#import "GoogleUtilities/UserDefaults/Public/GoogleUtilities/GULUserDefaults.h"

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULLogger.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kGULLogFormat = @"I-GUL%06ld";

static GULLoggerService kGULLogUserDefaultsService = @"[GoogleUtilities/UserDefaults]";

typedef NS_ENUM(NSInteger, GULUDMessageCode) {
  GULUDMessageCodeInvalidKeyGet = 1,
  GULUDMessageCodeInvalidKeySet = 2,
  GULUDMessageCodeInvalidObjectSet = 3,
  GULUDMessageCodeSynchronizeFailed = 4,
};

@interface GULUserDefaults ()

@property(nonatomic, readonly) NSUserDefaults *userDefaults;

@end

@implementation GULUserDefaults

+ (GULUserDefaults *)standardUserDefaults {
  static GULUserDefaults *standardUserDefaults;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    standardUserDefaults = [[GULUserDefaults alloc] init];
  });
  return standardUserDefaults;
}

- (instancetype)init {
  return [self initWithSuiteName:nil];
}

- (instancetype)initWithSuiteName:(nullable NSString *)suiteName {
  self = [super init];

  NSString *name = [suiteName copy];

  if (self) {
    _userDefaults = name.length ? [[NSUserDefaults alloc] initWithSuiteName:name]
                                : [NSUserDefaults standardUserDefaults];
  }

  return self;
}

- (nullable id)objectForKey:(NSString *)defaultName {
  NSString *key = [defaultName copy];
  if (![key isKindOfClass:[NSString class]] || !key.length) {
    GULOSLogWarning(kGULLogSubsystem, @"<GoogleUtilities>", NO,
                    [NSString stringWithFormat:kGULLogFormat, (long)GULUDMessageCodeInvalidKeyGet],
                    @"Cannot get object for invalid user default key.");
    return nil;
  }

  return [self.userDefaults objectForKey:key];
}

- (void)setObject:(nullable id)value forKey:(NSString *)defaultName {
  NSString *key = [defaultName copy];
  if (![key isKindOfClass:[NSString class]] || !key.length) {
    GULOSLogWarning(kGULLogSubsystem, kGULLogUserDefaultsService, NO,
                    [NSString stringWithFormat:kGULLogFormat, (long)GULUDMessageCodeInvalidKeySet],
                    @"Cannot set object for invalid user default key.");
    return;
  }
  if (!value) {
    [self.userDefaults removeObjectForKey:key];
    return;
  }
  // Validate the entire object graph rather than only the top-level class. NSUserDefaults aborts
  // the process on non-property-list content nested inside a collection, e.g. an NSNull decoded
  // from a JSON `null`, or a dictionary with non-string keys.
  BOOL isAcceptableValue =
      [NSPropertyListSerialization propertyList:value
                               isValidForFormat:NSPropertyListBinaryFormat_v1_0];
  if (!isAcceptableValue) {
    GULOSLogWarning(
        kGULLogSubsystem, kGULLogUserDefaultsService, NO,
        [NSString stringWithFormat:kGULLogFormat, (long)GULUDMessageCodeInvalidObjectSet],
        @"Cannot set invalid object to user defaults. Must be a string, number, array, "
        @"dictionary, date, or data. Value: %@",
        value);
    return;
  }

  [self.userDefaults setObject:value forKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
  [self setObject:nil forKey:key];
}

#pragma mark - Getters

// The typed getters below check the class of the stored value before using it, mirroring the type
// checks of the corresponding `NSUserDefaults` getters. Stored values may come from persisted
// (possibly server-derived) state, so a value of an unexpected type must not cause an
// unrecognized selector crash or be returned as the wrong type.

/// Returns the stored value if it responds to the numeric accessors (`NSNumber` or `NSString`),
/// otherwise `nil`.
- (nullable id)numericObjectForKey:(NSString *)defaultName {
  id object = [self objectForKey:defaultName];
  if ([object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSString class]]) {
    return object;
  }
  return nil;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
  return [[self numericObjectForKey:defaultName] integerValue];
}

- (float)floatForKey:(NSString *)defaultName {
  return [[self numericObjectForKey:defaultName] floatValue];
}

- (double)doubleForKey:(NSString *)defaultName {
  return [[self numericObjectForKey:defaultName] doubleValue];
}

- (BOOL)boolForKey:(NSString *)defaultName {
  return [[self numericObjectForKey:defaultName] boolValue];
}

- (nullable NSString *)stringForKey:(NSString *)defaultName {
  id object = [self objectForKey:defaultName];
  if ([object isKindOfClass:[NSString class]]) {
    return object;
  }
  if ([object isKindOfClass:[NSNumber class]]) {
    return [object stringValue];
  }
  return nil;
}

- (nullable NSArray *)arrayForKey:(NSString *)defaultName {
  id object = [self objectForKey:defaultName];
  return [object isKindOfClass:[NSArray class]] ? object : nil;
}

- (nullable NSDictionary<NSString *, id> *)dictionaryForKey:(NSString *)defaultName {
  id object = [self objectForKey:defaultName];
  return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

#pragma mark - Setters

- (void)setInteger:(NSInteger)integer forKey:(NSString *)defaultName {
  [self setObject:@(integer) forKey:defaultName];
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName {
  [self setObject:@(value) forKey:defaultName];
}

- (void)setDouble:(double)doubleNumber forKey:(NSString *)defaultName {
  [self setObject:@(doubleNumber) forKey:defaultName];
}

- (void)setBool:(BOOL)boolValue forKey:(NSString *)defaultName {
  [self setObject:@(boolValue) forKey:defaultName];
}

@end

NS_ASSUME_NONNULL_END
