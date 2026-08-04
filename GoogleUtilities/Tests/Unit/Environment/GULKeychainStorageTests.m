/*
 * Copyright 2019 Google
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

#import <TargetConditionals.h>

// Skip keychain tests on Catalyst and macOS. Tests are skipped because the
// implementation used to interact with the keychain requires signing with
// a provisioning profile that has the Keychain Sharing capability enabled.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

// Keychain tests require a host app and Swift Package Manager does not
// support adding a host app to test targets.
#if !SWIFT_PACKAGE

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Tests/Unit/Utils/GULTestKeychain.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainStorage.h"

@interface GULKeychainStorage (Tests)
- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache;
- (void)resetInMemoryCache;
@end

@interface GULFakeNSCache : NSCache

@property(nonatomic, assign) BOOL forceCacheMiss;

@property(nonatomic, assign) NSInteger objectForKeyCallCount;
@property(nonatomic, strong) id lastObjectForKey;

@property(nonatomic, assign) NSInteger setObjectCallCount;
@property(nonatomic, strong) id lastSetObjectKey;
@property(nonatomic, strong) id lastSetObject;

@property(nonatomic, assign) NSInteger removeObjectCallCount;
@property(nonatomic, strong) id lastRemoveObjectKey;

- (void)resetTrackers;

- (NSInteger)syncObjectForKeyCallCount;
- (id)syncLastObjectForKey;
- (NSInteger)syncSetObjectCallCount;
- (id)syncLastSetObjectKey;
- (id)syncLastSetObject;
- (NSInteger)syncRemoveObjectCallCount;
- (id)syncLastRemoveObjectKey;

@end

@implementation GULFakeNSCache

- (id)objectForKey:(id)key {
  @synchronized(self) {
    _objectForKeyCallCount++;
    _lastObjectForKey = key;
    if (_forceCacheMiss) {
      return nil;
    }
  }
  return [super objectForKey:key];
}

- (void)setObject:(id)obj forKey:(id)key {
  @synchronized(self) {
    _setObjectCallCount++;
    _lastSetObjectKey = key;
    _lastSetObject = obj;
  }
  [super setObject:obj forKey:key];
}

- (void)removeObjectForKey:(id)key {
  @synchronized(self) {
    _removeObjectCallCount++;
    _lastRemoveObjectKey = key;
  }
  [super removeObjectForKey:key];
}

- (void)resetTrackers {
  @synchronized(self) {
    _objectForKeyCallCount = 0;
    _lastObjectForKey = nil;
    _setObjectCallCount = 0;
    _lastSetObjectKey = nil;
    _lastSetObject = nil;
    _removeObjectCallCount = 0;
    _lastRemoveObjectKey = nil;
  }
}

- (NSInteger)syncObjectForKeyCallCount {
  @synchronized(self) {
    return _objectForKeyCallCount;
  }
}
- (id)syncLastObjectForKey {
  @synchronized(self) {
    return _lastObjectForKey;
  }
}
- (NSInteger)syncSetObjectCallCount {
  @synchronized(self) {
    return _setObjectCallCount;
  }
}
- (id)syncLastSetObjectKey {
  @synchronized(self) {
    return _lastSetObjectKey;
  }
}
- (id)syncLastSetObject {
  @synchronized(self) {
    return _lastSetObject;
  }
}
- (NSInteger)syncRemoveObjectCallCount {
  @synchronized(self) {
    return _removeObjectCallCount;
  }
}
- (id)syncLastRemoveObjectKey {
  @synchronized(self) {
    return _lastRemoveObjectKey;
  }
}

@end

@interface GULKeychainStorageTests : XCTestCase
@property(nonatomic, strong) GULKeychainStorage *storage;
@property(nonatomic, strong) GULFakeNSCache *fakeCache;

#if TARGET_OS_OSX
@property(nonatomic) GULTestKeychain *privateKeychain;
#endif  // TARGET_OS_OSX

@end

@implementation GULKeychainStorageTests

- (void)setUp {
  self.fakeCache = [[GULFakeNSCache alloc] init];
  self.storage = [[GULKeychainStorage alloc] initWithService:@"com.tests.GULKeychainStorageTests"
                                                       cache:self.fakeCache];

#if TARGET_OS_OSX
  self.privateKeychain = [[GULTestKeychain alloc] init];
  self.storage.keychainRef = self.privateKeychain.testKeychainRef;
#endif  // TARGET_OS_OSX
}

- (void)tearDown {
  self.storage = nil;
  self.fakeCache = nil;

#if TARGET_OS_OSX
  self.privateKeychain = nil;
#endif  // TARGET_OS_OSX
}

- (void)testSetGetObjectForKey {
  // 1. Write and read object initially.
  [self assertSuccessWriteObject:@[ @1, @2 ] forKey:@"test-key1"];
  [self assertSuccessReadObject:@[ @1, @2 ]
                         forKey:@"test-key1"
                          class:[NSArray class]
                  existsInCache:YES];

  //  // 2. Override existing object.
  [self assertSuccessWriteObject:@{@"key" : @"value"} forKey:@"test-key1"];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:YES];

  // 3. Read existing object which is not present in in-memory cache.
  [self.fakeCache removeAllObjects];
  // TODO: Evaluate if GULKeychainStorage needs an API that takes set of classes. (#42)
  // The following method causes an NSKeyedUnarchiver-related runtime warning log.
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:NO];

  // 4. Write and read an object for another key.
  [self assertSuccessWriteObject:@{@"key" : @"value"} forKey:@"test-key2"];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key2"
                          class:[NSDictionary class]
                  existsInCache:YES];
}

- (void)testGetNonExistingObject {
  [self assertNonExistingObjectForKey:[NSUUID UUID].UUIDString class:[NSArray class]];
}

- (void)testGetExistingObjectClassMismatch {
  NSString *key = [NSUUID UUID].UUIDString;

  // Write.
  [self assertSuccessWriteObject:@[ @8 ] forKey:key];

  // Read.
  // Skip in-memory cache because the error is relevant only for Keychain.
  self.fakeCache.forceCacheMiss = YES;
  [self.fakeCache resetTrackers];

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  [self.storage getObjectForKey:key
                    objectClass:[NSString class]
                    accessGroup:nil
              completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
                XCTAssertNil(obj);
                // Assert class mismatch error.
                XCTAssertNotNil(error);
                XCTAssertEqual(error.domain, NSCocoaErrorDomain);
                XCTAssertEqual(error.code, 4864);

                XCTAssertEqual([self.fakeCache syncObjectForKeyCallCount], 1);
                [expectation fulfill];
              }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)testRemoveExistingObject {
  NSString *key = @"testRemoveExistingObject";
  // Store the object.
  [self assertSuccessWriteObject:@[ @5 ] forKey:(NSString *)key];

  // Remove object.
  [self assertRemoveObjectForKey:key];

  // Check if object is still stored.
  [self assertNonExistingObjectForKey:key class:[NSArray class]];
}

- (void)testRemoveNonExistingObject {
  NSString *key = [NSUUID UUID].UUIDString;
  [self assertRemoveObjectForKey:key];
  [self assertNonExistingObjectForKey:key class:[NSArray class]];
}

#pragma mark - Common

- (void)assertSuccessWriteObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
  [self.fakeCache resetTrackers];

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __weak __auto_type weakSelf = self;
  [self.storage setObject:object
                   forKey:key
              accessGroup:nil
        completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
          if (!weakSelf) {
            return;
          }
          XCTAssertNil(error, @"%@", weakSelf.name);
          XCTAssertEqual([weakSelf.fakeCache syncSetObjectCallCount], 1);
          XCTAssertEqualObjects([weakSelf.fakeCache syncLastSetObjectKey], key);
          [expectation fulfill];
        }];

  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)assertSuccessReadObject:(id<NSSecureCoding>)object
                         forKey:(NSString *)key
                          class:(Class)class
                  existsInCache:(BOOL)existisInCache {
  [self.fakeCache resetTrackers];

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __weak __auto_type weakSelf = self;
  [self.storage getObjectForKey:key
                    objectClass:class
                    accessGroup:nil
              completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
                if (!weakSelf) {
                  return;
                }
                XCTAssertEqualObjects(obj, object, @"%@", weakSelf.name);
                XCTAssertNil(error, @"%@", weakSelf.name);
                XCTAssertEqual([weakSelf.fakeCache syncObjectForKeyCallCount], 1);
                XCTAssertEqualObjects([weakSelf.fakeCache syncLastObjectForKey], key);

                if (!existisInCache) {
                  XCTAssertEqual([weakSelf.fakeCache syncSetObjectCallCount], 1);
                  XCTAssertEqualObjects([weakSelf.fakeCache syncLastSetObjectKey], key);
                }

                [expectation fulfill];
              }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)assertNonExistingObjectForKey:(NSString *)key class:(Class)class {
  [self.fakeCache resetTrackers];

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __weak __auto_type weakSelf = self;
  [self.storage getObjectForKey:key
                    objectClass:class
                    accessGroup:nil
              completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
                if (!weakSelf) {
                  return;
                }
                XCTAssertNil(error, @"%@", weakSelf.name);
                XCTAssertNil(obj, @"%@", weakSelf.name);
                XCTAssertEqual([weakSelf.fakeCache syncObjectForKeyCallCount], 1);
                XCTAssertEqualObjects([weakSelf.fakeCache syncLastObjectForKey], key);
                [expectation fulfill];
              }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

- (void)assertRemoveObjectForKey:(NSString *)key {
  [self.fakeCache resetTrackers];

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __weak __auto_type weakSelf = self;
  [self.storage removeObjectForKey:key
                       accessGroup:nil
                 completionHandler:^(NSError *_Nullable error) {
                   XCTAssertNil(error);
                   XCTAssertEqual([weakSelf.fakeCache syncRemoveObjectCallCount], 1);
                   XCTAssertEqualObjects([weakSelf.fakeCache syncLastRemoveObjectKey], key);
                   [expectation fulfill];
                 }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
}

@end

#endif  // SWIFT_PACKAGE
#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
