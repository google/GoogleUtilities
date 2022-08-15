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
#if !TARGET_OS_MACCATALYST
// Skip keychain tests on Catalyst.

#if !SWIFT_PACKAGE
// TODO: Investigate why keychain tests fail on iOS with Swift Package Manager.
// Keychain tests need a host app.

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"
#import "GoogleUtilities/Tests/Unit/Utils/GULTestKeychain.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainStorage.h"
#import "GoogleUtilities/Tests/Unit/Environment/Sources/GULKeychainStorageV7.7.0.h"

static NSString *const kKeychainServiceName = @"com.tests.GULKeychainStorageTests";

@interface GULKeychainStorage (Tests)
- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache;
- (void)resetInMemoryCache;
@end

@interface GULKeychainStorageV7_7_0 (Tests)
- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache;
- (void)resetInMemoryCache;
@end

@interface GULKeychainStorageTests : XCTestCase
@property(nonatomic) GULKeychainStorage *storage;
@property(nonatomic) id mockCache;

#if TARGET_OS_OSX
@property(nonatomic) GULTestKeychain *privateKeychain;
#endif  // TARGET_OS_OSX

@end

@implementation GULKeychainStorageTests

- (void)setUp {
  self.mockCache = OCMPartialMock([[NSCache alloc] init]);
  self.storage = [[GULKeychainStorage alloc] initWithService:kKeychainServiceName
                                                       cache:self.mockCache];

#if TARGET_OS_OSX
  self.privateKeychain = [[GULTestKeychain alloc] init];
  self.storage.keychainRef = self.privateKeychain.testKeychainRef;
#endif  // TARGET_OS_OSX
}

- (void)tearDown {
  self.storage = nil;
  self.mockCache = nil;

#if TARGET_OS_OSX
  self.privateKeychain = nil;
#endif  // TARGET_OS_OSX
}

- (void)testSetGetObjectForKey {
  // 1. Write and read object initially.
  [self assertSuccessWriteObject:@[ @1, @2 ]
                          forKey:@"test-key1"
                       toStorage:self.storage
                   withMockCache:self.mockCache];

  [self assertSuccessReadObject:@[ @1, @2 ]
                         forKey:@"test-key1"
                          class:[NSArray class]
                  existsInCache:YES
                    fromStorage:self.storage
                  withMockCache:self.mockCache];

  //  // 2. Override existing object.
  [self assertSuccessWriteObject:@{@"key" : @"value"}
                          forKey:@"test-key1"
                       toStorage:self.storage
                   withMockCache:self.mockCache];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:YES
                    fromStorage:self.storage
                  withMockCache:self.mockCache];

  // 3. Read existing object which is not present in in-memory cache.
  [self.mockCache removeAllObjects];
  // TODO: Evaluate if GULKeychainStorage needs an API that takes set of classes. (#42)
  // The following method causes an NSKeyedUnarchiver-related runtime warning log.
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:NO
                    fromStorage:self.storage
                  withMockCache:self.mockCache];

  // 4. Write and read an object for another key.
  [self assertSuccessWriteObject:@{@"key" : @"value"}
                          forKey:@"test-key2"
                       toStorage:self.storage
                   withMockCache:self.mockCache];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key2"
                          class:[NSDictionary class]
                  existsInCache:YES
                    fromStorage:self.storage
                  withMockCache:self.mockCache];
}

- (void)testGetNonExistingObject {
  [self assertNonExistingObjectForKey:[NSUUID UUID].UUIDString class:[NSArray class]];
}

- (void)testGetExistingObjectClassMismatch {
  NSString *key = [NSUUID UUID].UUIDString;

  // Write.
  [self assertSuccessWriteObject:@[ @8 ]
                          forKey:key
                       toStorage:self.storage
                   withMockCache:self.mockCache];

  // Read.
  // Skip in-memory cache because the error is relevant only for Keychain.
  OCMExpect([self.mockCache objectForKey:key]).andReturn(nil);

  FBLPromise<id<NSSecureCoding>> *getPromise = [self.storage getObjectForKey:key
                                                                 objectClass:[NSString class]
                                                                 accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(getPromise.value);
  XCTAssertNotNil(getPromise.error);
  // TODO: Test for particular error.

  OCMVerifyAll(self.mockCache);
}

- (void)testRemoveExistingObject {
  NSString *key = @"testRemoveExistingObject";
  // Store the object.
  [self assertSuccessWriteObject:@[ @5 ]
                          forKey:(NSString *)key
                       toStorage:self.storage
                   withMockCache:self.mockCache];

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

#pragma mark - Version Compatibility

- (void)FAILS_testVersionCompatibility_GetObject {
  // Given
  // - Object is set with old implementation.
  id oldMockCache = OCMPartialMock([[NSCache alloc] init]);
  GULKeychainStorageV7_7_0 *oldKeychainStorage =
      [[GULKeychainStorageV7_7_0 alloc] initWithService:kKeychainServiceName cache:oldMockCache];

  [self assertSuccessWriteObject:@100
                          forKey:@"test-key1"
                       toStorage:(GULKeychainStorage *)oldKeychainStorage
                   withMockCache:oldMockCache];

  // When
  // - App is updated to include a Google Utilities version greater than 7.7.0.

  // Then
  // - Object is retrieved with new implementation.
  [self.mockCache removeAllObjects];
  [self assertSuccessReadObject:@100
                         forKey:@"test-key1"
                          class:[NSNumber class]
                  existsInCache:YES
                    fromStorage:self.storage
                  withMockCache:self.mockCache];
}

- (void)testVersionCompatibility_SetObject {
  // Given
  // - Object is set with old implementation.
  id oldMockCache = OCMPartialMock([[NSCache alloc] init]);
  GULKeychainStorageV7_7_0 *oldKeychainStorage =
      [[GULKeychainStorageV7_7_0 alloc] initWithService:kKeychainServiceName cache:oldMockCache];

  [self assertSuccessWriteObject:@100
                          forKey:@"test-key1"
                       toStorage:(GULKeychainStorage *)oldKeychainStorage
                   withMockCache:oldMockCache];

  // When
  // - App is updated to include a Google Utilities version greater than 7.7.0.

  // Then
  // - The same object is updated with new implementation.
  [self assertSuccessWriteObject:@200
                          forKey:@"test-key1"
                       toStorage:self.storage
                   withMockCache:self.mockCache];

  [self assertSuccessReadObject:@200
                         forKey:@"test-key1"
                          class:[NSNumber class]
                  existsInCache:YES
                    fromStorage:self.storage
                  withMockCache:self.mockCache];

  [oldMockCache removeAllObjects];
  [self assertSuccessReadObject:@200
                         forKey:@"test-key1"
                          class:[NSNumber class]
                  existsInCache:NO
                    fromStorage:(GULKeychainStorage *)oldKeychainStorage
                  withMockCache:oldMockCache];
}

- (void)testVersionCompatibility_RemoveObject {
  // Given
  // - Object is set with old implementation.
  [self assertNonExistingObjectForKey:@"test-key1" class:[NSNumber class]];

  id oldMockCache = OCMPartialMock([[NSCache alloc] init]);
  GULKeychainStorageV7_7_0 *oldKeychainStorage =
      [[GULKeychainStorageV7_7_0 alloc] initWithService:kKeychainServiceName cache:oldMockCache];

  [self assertSuccessWriteObject:@100
                          forKey:@"test-key1"
                       toStorage:(GULKeychainStorage *)oldKeychainStorage
                   withMockCache:oldMockCache];

  // When
  // - App is updated to include a Google Utilities version greater than 7.7.0.

  // Then
  // - The same object is removed with new implementation.
  [self assertRemoveObjectForKey:@"test-key1"];

  [oldMockCache removeAllObjects];
  [self assertSuccessReadObject:@100
                         forKey:@"test-key1"
                          class:[NSNumber class]
                  existsInCache:NO
                    fromStorage:(GULKeychainStorage *)oldKeychainStorage
                  withMockCache:oldMockCache];
}

#pragma mark - Common

- (void)assertSuccessWriteObject:(id<NSSecureCoding>)object
                          forKey:(NSString *)key
                       toStorage:(GULKeychainStorage *)storage
                   withMockCache:(id)mockCache {
  OCMExpect([mockCache setObject:object forKey:key]).andForwardToRealObject();

  FBLPromise<NSNull *> *setPromise = [storage setObject:object forKey:key accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(setPromise.error, @"%@", self.name);

  OCMVerifyAll(mockCache);

  // Check in-memory cache.
  XCTAssertEqualObjects([mockCache objectForKey:key], object);
}

- (void)assertSuccessReadObject:(id<NSSecureCoding>)object
                         forKey:(NSString *)key
                          class:(Class)class
                  existsInCache:(BOOL)existisInCache
                    fromStorage:(GULKeychainStorage *)storage
                  withMockCache:(id)mockCache {
  OCMExpect([mockCache objectForKey:key]).andForwardToRealObject();

  if (!existisInCache) {
    OCMExpect([mockCache setObject:object forKey:key]).andForwardToRealObject();
  }

  FBLPromise<id<NSSecureCoding>> *getPromise =
      [storage getObjectForKey:key objectClass:class accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1), @"%@", self.name);
  XCTAssertEqualObjects(getPromise.value, object, @"%@", self.name);
  XCTAssertNil(getPromise.error, @"%@", self.name);

  OCMVerifyAll(mockCache);

  // Check in-memory cache.
  XCTAssertEqualObjects([mockCache objectForKey:key], object, @"%@", self.name);
}

- (void)assertNonExistingObjectForKey:(NSString *)key class:(Class)class {
  OCMExpect([self.mockCache objectForKey:key]).andForwardToRealObject();

  FBLPromise<id<NSSecureCoding>> *promise =
      [self.storage getObjectForKey:key objectClass:class accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(promise.error, @"%@", self.name);
  XCTAssertNil(promise.value, @"%@", self.name);

  OCMVerifyAll(self.mockCache);
}

- (void)assertRemoveObjectForKey:(NSString *)key {
  OCMExpect([self.mockCache removeObjectForKey:key]).andForwardToRealObject();

  FBLPromise<NSNull *> *removePromise = [self.storage removeObjectForKey:key accessGroup:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(removePromise.error);

  OCMVerifyAll(self.mockCache);
}

@end

#endif  // SWIFT_PACKAGE
#endif  // TARGET_OS_MACCATALYST
