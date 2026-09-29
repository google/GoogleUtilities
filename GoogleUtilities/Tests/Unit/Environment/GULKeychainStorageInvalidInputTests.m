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
