// Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULSecureCoding.h"

@interface SecureCodingIncompatibleObject : NSObject <NSCoding>
@end

@implementation SecureCodingIncompatibleObject

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  return [self init];
}

@end

@interface GULSecureCodingTests : XCTestCase

@end

@implementation GULSecureCodingTests

- (void)SKIP_testArchiveUnarchiveSingleClass {
  NSDictionary *objectToArchive = @{};

  NSError *error;
  NSData *archiveData = [GULSecureCoding archivedDataWithRootObject:objectToArchive error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(archiveData);

  NSDictionary *unarchivedObject = [GULSecureCoding unarchivedObjectOfClass:[NSDictionary class]
                                                                   fromData:archiveData
                                                                      error:&error];
  XCTAssertNil(error);
  XCTAssert([objectToArchive isEqualToDictionary:unarchivedObject]);
}

- (void)SKIP_testArchiveUnarchiveMultipleClasses {
  NSDictionary *objectToArchive = @{@"key1" : [NSDate date], @"key2" : @(2)};

  NSError *error;
  NSData *archiveData = [GULSecureCoding archivedDataWithRootObject:objectToArchive error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(archiveData);

  NSDictionary *unarchivedObject = [GULSecureCoding
      unarchivedObjectOfClasses:
          [NSSet setWithArray:@[ NSDictionary.class, NSDate.class, NSString.class, NSNumber.class ]]
                       fromData:archiveData
                          error:&error];
  XCTAssertNil(error);
  XCTAssert([objectToArchive isEqualToDictionary:unarchivedObject]);
}

- (void)SKIP_testArchivingIncompatibleObjectError {
  SecureCodingIncompatibleObject *objectToArchive = [[SecureCodingIncompatibleObject alloc] init];

  NSError *error;
  NSData *archiveData = [GULSecureCoding archivedDataWithRootObject:objectToArchive error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(archiveData);
}

- (void)SKIP_testUnarchivingClassMismatchError {
  NSDictionary *objectToArchive = @{@"key1" : @"value1", @"key2" : @(2)};
  NSError *error;
  NSData *archiveData = [GULSecureCoding archivedDataWithRootObject:objectToArchive error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(archiveData);

  NSArray *unarchivedObject = [GULSecureCoding unarchivedObjectOfClass:[NSArray class]
                                                              fromData:archiveData
                                                                 error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(unarchivedObject);
}

- (void)SKIP_testUnarchivingCorruptedDataError {
  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSString *unarchivedObject = [GULSecureCoding unarchivedObjectOfClass:[NSString class]
                                                               fromData:corruptedData
                                                                  error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(unarchivedObject);
}

- (void)SKIP_testArchiveUnarchiveWithNULLError {
  SecureCodingIncompatibleObject *objectToArchive = [[SecureCodingIncompatibleObject alloc] init];

  NSData *archiveData = [GULSecureCoding archivedDataWithRootObject:objectToArchive error:NULL];
  XCTAssertNil(archiveData);

  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *unarchivedObject = [GULSecureCoding unarchivedObjectOfClass:[NSDictionary class]
                                                                   fromData:corruptedData
                                                                      error:NULL];
  XCTAssertNil(unarchivedObject);
}

@end
