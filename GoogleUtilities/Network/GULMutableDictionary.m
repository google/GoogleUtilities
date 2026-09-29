// Copyright 2017 Google
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

#import "GoogleUtilities/Network/Public/GoogleUtilities/GULMutableDictionary.h"

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULLogger.h"
#import "GoogleUtilities/Network/GULNetworkInternal.h"
#import "GoogleUtilities/Network/Public/GoogleUtilities/GULNetworkMessageCode.h"

/// Logs a write that was dropped because of a nil argument. Dropping the write avoids a crash, and
/// the log keeps the caller's bug visible.
static void GULMutableDictionaryLogIgnoredWrite(GULNetworkMessageCode messageCode,
                                                SEL selector,
                                                NSString *reason) {
  GULOSLogWarning(kGULLogSubsystem, kGULLoggerNetwork, NO,
                  [NSString stringWithFormat:@"I-NET%06ld", (long)messageCode],
                  @"GULMutableDictionary ignored -%@ because %@.", NSStringFromSelector(selector),
                  reason);
}

@implementation GULMutableDictionary {
  /// The mutable dictionary.
  NSMutableDictionary *_objects;

  /// Serial synchronization queue. All reads should use dispatch_sync, while writes use
  /// dispatch_async.
  dispatch_queue_t _queue;
}

- (instancetype)init {
  self = [super init];

  if (self) {
    _objects = [[NSMutableDictionary alloc] init];
    _queue = dispatch_queue_create("GULMutableDictionary", DISPATCH_QUEUE_SERIAL);
  }

  return self;
}

- (NSString *)description {
  __block NSString *description;
  dispatch_sync(_queue, ^{
    description = self->_objects.description;
  });
  return description;
}

- (id)objectForKey:(id)key {
  __block id object;
  dispatch_sync(_queue, ^{
    object = [self->_objects objectForKey:key];
  });
  return object;
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key {
  // NSMutableDictionary throws on a nil key or object. Because the write runs asynchronously, the
  // exception would be raised on the internal queue, where the caller cannot catch it and the crash
  // is attributed to GoogleUtilities.
  if (key == nil) {
    GULMutableDictionaryLogIgnoredWrite(kGULNetworkMessageCodeMutableDictionary000, _cmd,
                                        @"the key is nil");
    return;
  }
  if (object == nil) {
    GULMutableDictionaryLogIgnoredWrite(kGULNetworkMessageCodeMutableDictionary001, _cmd,
                                        @"the object is nil");
    return;
  }
  dispatch_async(_queue, ^{
    [self->_objects setObject:object forKey:key];
  });
}

- (void)removeObjectForKey:(id)key {
  if (key == nil) {
    GULMutableDictionaryLogIgnoredWrite(kGULNetworkMessageCodeMutableDictionary000, _cmd,
                                        @"the key is nil");
    return;
  }
  dispatch_async(_queue, ^{
    [self->_objects removeObjectForKey:key];
  });
}

- (void)removeAllObjects {
  dispatch_async(_queue, ^{
    [self->_objects removeAllObjects];
  });
}

- (NSUInteger)count {
  __block NSUInteger count;
  dispatch_sync(_queue, ^{
    count = self->_objects.count;
  });
  return count;
}

- (id)objectForKeyedSubscript:(id<NSCopying>)key {
  __block id object;
  dispatch_sync(_queue, ^{
    object = self->_objects[key];
  });
  return object;
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
  // A nil object removes the key, but a nil key would throw on the internal queue.
  if (key == nil) {
    GULMutableDictionaryLogIgnoredWrite(kGULNetworkMessageCodeMutableDictionary000, _cmd,
                                        @"the key is nil");
    return;
  }
  dispatch_async(_queue, ^{
    self->_objects[key] = obj;
  });
}

- (NSDictionary *)dictionary {
  __block NSDictionary *dictionary;
  dispatch_sync(_queue, ^{
    dictionary = [self->_objects copy];
  });
  return dictionary;
}

@end
