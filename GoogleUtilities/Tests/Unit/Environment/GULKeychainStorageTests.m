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

#import <OCMock/OCMock.h>
#import "GoogleUtilities/Tests/Unit/Utils/GULTestKeychain.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainStorage.h"

@interface GULKeychainStorage (Tests)
- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache;
- (void)resetInMemoryCache;
@end

@interface GULKeychainStorageTests : XCTestCase
@property(nonatomic, strong) GULKeychainStorage *storage;
@property(nonatomic, strong) NSCache *cache;
@property(nonatomic, strong) id mockCache;

#if TARGET_OS_OSX
@property(nonatomic) GULTestKeychain *privateKeychain;
#endif  // TARGET_OS_OSX

@end

@implementation GULKeychainStorageTests

- (void)setUp {
  self.cache = [[NSCache alloc] init];
  self.mockCache = OCMPartialMock(self.cache);
  self.storage = [[GULKeychainStorage alloc] initWithService:@"com.tests.GULKeychainStorageTests"
                                                       cache:self.mockCache];

#if TARGET_OS_OSX
  self.privateKeychain = [[GULTestKeychain alloc] init];
  self.storage.keychainRef = self.privateKeychain.testKeychainRef;
#endif  // TARGET_OS_OSX
}

- (void)tearDown {
  self.storage = nil;
  self.mockCache = nil;
  self.cache = nil;

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
  [self.cache removeAllObjects];
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
  OCMExpect([self.mockCache objectForKey:key]).andReturn(nil);

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

                OCMVerifyAll(self.mockCache);
                [expectation fulfill];
              }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
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
  OCMExpect([self.mockCache setObject:object forKey:key]).andForwardToRealObject();

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
          // Check in-memory cache.
          XCTAssertEqualObjects([weakSelf.cache objectForKey:key], object);
          [expectation fulfill];
        }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];
  OCMVerifyAll(self.mockCache);
}

- (void)assertSuccessReadObject:(id<NSSecureCoding>)object
                         forKey:(NSString *)key
                          class:(Class)class
                  existsInCache:(BOOL)existisInCache {
  OCMExpect([self.mockCache objectForKey:key]).andForwardToRealObject();

  if (!existisInCache) {
    OCMExpect([self.mockCache setObject:object forKey:key]).andForwardToRealObject();
  }

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __weak __auto_type weakSelf = self;
  [self.storage
        getObjectForKey:key
            objectClass:class
            accessGroup:nil
      completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
        if (!weakSelf) {
          return;
        }
        XCTAssertEqualObjects(obj, object, @"%@", weakSelf.name);
        XCTAssertNil(error, @"%@", weakSelf.name);
        // Check in-memory cache.
        XCTAssertEqualObjects([weakSelf.cache objectForKey:key], object, @"%@", weakSelf.name);
        [expectation fulfill];
      }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
  OCMVerifyAll(self.mockCache);
}

- (void)assertNonExistingObjectForKey:(NSString *)key class:(Class)class {
  OCMExpect([self.mockCache objectForKey:key]).andForwardToRealObject();

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
                [expectation fulfill];
              }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
  OCMVerifyAll(self.mockCache);
}

- (void)assertRemoveObjectForKey:(NSString *)key {
  OCMExpect([self.mockCache removeObjectForKey:key]).andForwardToRealObject();

  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  [self.storage removeObjectForKey:key
                       accessGroup:nil
                 completionHandler:^(NSError *_Nullable error) {
                   XCTAssertNil(error);
                   [expectation fulfill];
                 }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
  OCMVerifyAll(self.mockCache);
}

@end

#endif  // SWIFT_PACKAGE
#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
