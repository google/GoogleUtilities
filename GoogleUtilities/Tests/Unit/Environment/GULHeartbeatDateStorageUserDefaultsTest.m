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

#import <XCTest/XCTest.h>
#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULHeartbeatDateStorageUserDefaults.h"

@interface GULHeartbeatDateStorageUserDefaultsTest : XCTestCase
@property(nonatomic) GULHeartbeatDateStorageUserDefaults *storage;
@property(nonatomic) NSUserDefaults *defaults;
@end

@implementation GULHeartbeatDateStorageUserDefaultsTest

- (void)setUp {
  NSString *suiteName = [self userDefaultsSuiteName];
  self.defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  self.storage = [[GULHeartbeatDateStorageUserDefaults alloc] initWithDefaults:self.defaults
                                                                           key:@"test_root"];
}

- (void)tearDown {
  [self.defaults removePersistentDomainForName:[self userDefaultsSuiteName]];
  self.defaults = nil;

  self.storage = nil;
}

#pragma mark - Public API Tests

- (void)testHeartbeatDateForTag {
  // 1. Tag and save some heartbeat info.
  NSDate *storedDate = [NSDate date];
  NSString *tag = @"fire-iid";
  [self.storage setHearbeatDate:storedDate forTag:tag];

  // 2. Retrieve the stored heartbeat info and assert the retrieved info is accurate.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertEqualObjects(retrievedDate, storedDate);
}

- (void)testHeartbeatDateForTagWhenReturnedDateIsNil {
  NSString *nonexistentTag = @"missing-tag";
  NSDate *nilDate = [self.storage heartbeatDateForTag:nonexistentTag];
  XCTAssertNil(nilDate);
}

- (void)testSetHeartbeatDateForTag {
  NSDate *date = [NSDate date];
  NSString *tag = @"tag";

  // 1. Retrieve heartbeat info that is not stored and assert the retrieved info is nil.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertNil(retrievedDate);

  // 2. Save the heartbeat info and assert the save was successful.
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);

  // 3. Retrieve heartbeat info that is now stored and assert the retrieved info is accurate.
  retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertEqualObjects(retrievedDate, date);
}

- (void)testConformsToHeartbeatStorableProtocol {
  XCTAssertTrue([self.storage conformsToProtocol:@protocol(GULHeartbeatDateStorable)]);
}

#pragma mark - Testing Utilities

- (NSString *)userDefaultsSuiteName {
  NSCharacterSet *lettersToTrim = [[NSCharacterSet letterCharacterSet] invertedSet];
  NSString *nameWithSpaces = [self.name stringByTrimmingCharactersInSet:lettersToTrim];
  return [nameWithSpaces stringByReplacingOccurrencesOfString:@" " withString:@"_"];
}

@end
