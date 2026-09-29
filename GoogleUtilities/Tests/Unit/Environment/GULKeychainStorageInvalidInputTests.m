/*
 * Copyright 2026 Google LLC
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

// Invalid input is rejected before the keychain is accessed, so unlike GULKeychainStorageTests
// these tests do not need a host app or keychain entitlements and run on every platform.

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainStorage.h"
#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainUtils.h"

static NSString *const kInvalidKeyReason = @"Key must be a non-empty string.";

@interface GULKeychainStorage (Tests)
+ (nullable id)unarchivedObjectOfClass:(Class)objectClass
                              fromData:(NSData *)data
                                 error:(NSError **)outError;
@end

/// Simulates a class whose `-initWithCoder:` raises while decoding corrupted keychain data.
@interface GULThrowingSecureCodingObject : NSObject <NSSecureCoding>
@end

@implementation GULThrowingSecureCodingObject
+ (BOOL)supportsSecureCoding {
  return YES;
}
- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:@"value" forKey:@"key"];
}
- (instancetype)initWithCoder:(NSCoder *)coder {
  [NSException raise:NSInvalidArgumentException format:@"Corrupted keychain data"];
  return nil;
}
@end

@interface GULKeychainStorageInvalidInputTests : XCTestCase
@property(nonatomic, strong) GULKeychainStorage *storage;
@end

@implementation GULKeychainStorageInvalidInputTests

- (void)setUp {
  self.storage =
      [[GULKeychainStorage alloc] initWithService:@"com.tests.GULKeychainStorageInvalidInputTests"];
}

- (void)tearDown {
  self.storage = nil;
}

// The completion blocks only record their results. Assertions run after the wait because
// XCTAssert* macros reference `self`, and capturing `self` in a block retained by `self.storage`
// triggers -Warc-retain-cycles.

- (void)testSetNilObjectReturnsError {
  id nilObject = nil;
  XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
  __block id<NSSecureCoding> resultObject;
  __block NSError *resultError;
  [self.storage setObject:nilObject
                   forKey:@"key"
              accessGroup:nil
        completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
          resultObject = obj;
          resultError = error;
          [expectation fulfill];
        }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];

  XCTAssertNil(resultObject);
  [self assertError:resultError hasReason:@"Object must not be nil."];
}

- (void)testSetWithInvalidKeysReturnsError {
  for (id candidate in [self invalidKeys]) {
    id key = [self keyFromCandidate:candidate];
    XCTestExpectation *expectation = [self expectationWithDescription:[candidate description]];
    __block id<NSSecureCoding> resultObject;
    __block NSError *resultError;
    [self.storage setObject:@"value"
                     forKey:key
                accessGroup:nil
          completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
            resultObject = obj;
            resultError = error;
            [expectation fulfill];
          }];
    [self waitForExpectations:@[ expectation ] timeout:5.0];

    XCTAssertNil(resultObject, @"%@", candidate);
    [self assertError:resultError hasReason:kInvalidKeyReason];
  }
}

- (void)testGetWithInvalidKeysReturnsError {
  for (id candidate in [self invalidKeys]) {
    id key = [self keyFromCandidate:candidate];
    XCTestExpectation *expectation = [self expectationWithDescription:[candidate description]];
    __block id<NSSecureCoding> resultObject;
    __block NSError *resultError;
    [self.storage getObjectForKey:key
                      objectClass:[NSString class]
                      accessGroup:nil
                completionHandler:^(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error) {
                  resultObject = obj;
                  resultError = error;
                  [expectation fulfill];
                }];
    [self waitForExpectations:@[ expectation ] timeout:5.0];

    XCTAssertNil(resultObject, @"%@", candidate);
    [self assertError:resultError hasReason:kInvalidKeyReason];
  }
}

- (void)testRemoveWithInvalidKeysReturnsError {
  for (id candidate in [self invalidKeys]) {
    id key = [self keyFromCandidate:candidate];
    XCTestExpectation *expectation = [self expectationWithDescription:[candidate description]];
    __block NSError *resultError;
    [self.storage removeObjectForKey:key
                         accessGroup:nil
                   completionHandler:^(NSError *_Nullable error) {
                     resultError = error;
                     [expectation fulfill];
                   }];
    [self waitForExpectations:@[ expectation ] timeout:5.0];

    [self assertError:resultError hasReason:kInvalidKeyReason];
  }
}

#pragma mark - Decoding

- (void)testUnarchiveValidObject {
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@[ @1, @2 ]
                                       requiringSecureCoding:YES
                                                       error:NULL];
  NSError *error;
  id object = [GULKeychainStorage unarchivedObjectOfClass:[NSArray class]
                                                 fromData:data
                                                    error:&error];
  XCTAssertEqualObjects(object, (@[ @1, @2 ]));
  XCTAssertNil(error);
}

- (void)testUnarchiveExceptionInInitWithCoderReturnsError {
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[GULThrowingSecureCodingObject new]
                                       requiringSecureCoding:YES
                                                       error:NULL];
  XCTAssertNotNil(data);
  NSError *error;
  id object = [GULKeychainStorage unarchivedObjectOfClass:[GULThrowingSecureCodingObject class]
                                                 fromData:data
                                                    error:&error];
  XCTAssertNil(object);
  XCTAssertEqualObjects(error.domain, kGULKeychainUtilsErrorDomain);
  XCTAssertTrue(
      [error.userInfo[NSLocalizedFailureReasonErrorKey] containsString:@"Corrupted keychain data"]);
}

- (void)testUnarchiveWithNilClassReturnsError {
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@"value"
                                       requiringSecureCoding:YES
                                                       error:NULL];
  Class nilClass = Nil;
  NSError *error;
  id object = [GULKeychainStorage unarchivedObjectOfClass:nilClass fromData:data error:&error];
  XCTAssertNil(object);
  XCTAssertEqualObjects(error.domain, kGULKeychainUtilsErrorDomain);
}

- (void)testUnarchiveMalformedDataReturnsError {
  NSData *data = [@"not an archive" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  id object = [GULKeychainStorage unarchivedObjectOfClass:[NSString class]
                                                 fromData:data
                                                    error:&error];
  XCTAssertNil(object);
  XCTAssertNotNil(error);
}

#pragma mark - Helpers

/// Keys that must be rejected. `NSNull` stands in for a nil key, since arrays cannot hold nil.
- (NSArray *)invalidKeys {
  return @[ [NSNull null], @"", @123 ];
}

- (id)keyFromCandidate:(id)candidate {
  return candidate == [NSNull null] ? nil : candidate;
}

/// Checks the specific reason so that the test cannot pass on an unrelated keychain error (e.g. a
/// missing entitlement on macOS), which uses the same error domain.
- (void)assertError:(NSError *)error hasReason:(NSString *)reason {
  XCTAssertNotNil(error);
  XCTAssertEqualObjects(error.domain, kGULKeychainUtilsErrorDomain);
  XCTAssertEqualObjects(error.userInfo[NSLocalizedFailureReasonErrorKey], reason);
}

@end
