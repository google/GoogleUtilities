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
}

- (void)testHeartbeatDateForTag {
  NSDate *now = [NSDate date];
  [self.storage setHearbeatDate:now forTag:@"fire-iid"];
  XCTAssertEqual([now timeIntervalSinceReferenceDate],
                 [[self.storage heartbeatDateForTag:@"fire-iid"] timeIntervalSinceReferenceDate]);
}

- (void)testConformsToHeartbeatStorableProtocol {
  XCTAssertTrue([self.storage conformsToProtocol:@protocol(GULHeartbeatDateStorable)]);
}

#pragma mark - Private Helpers

- (NSString *)userDefaultsSuiteName {
  NSCharacterSet *lettersToTrim = [[NSCharacterSet letterCharacterSet] invertedSet];
  NSString *nameWithSpaces = [self.name stringByTrimmingCharactersInSet:lettersToTrim];
  return [nameWithSpaces stringByReplacingOccurrencesOfString:@" " withString:@"_"];
}

@end
