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
#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULHeartbeatDateStorage.h"

@interface GULHeartbeatDateStorageTest : XCTestCase
@property(nonatomic) GULHeartbeatDateStorage *storage;
#if TARGET_OS_TV
@property(nonatomic) NSUserDefaults *defaults;
#endif  // TARGET_OS_TV
@end

static NSString *const kTestFileName = @"GULStorageHeartbeatTest";

@implementation GULHeartbeatDateStorageTest

#if TARGET_OS_TV
- (void)setUp {
  NSString *suiteName = [self userDefaultsSuiteName];
  self.defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  self.storage = [[GULHeartbeatDateStorage alloc] initWithDefaults:self.defaults key:@"test_root"];
}
#else
- (void)setUp {
  NSArray *path =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *rootPath = [path firstObject];
  XCTAssertNotNil(rootPath);
  NSURL *rootURL = [NSURL fileURLWithPath:rootPath];

  NSError *error;
  if (![rootURL checkResourceIsReachableAndReturnError:&error]) {
    XCTAssert([[NSFileManager defaultManager] createDirectoryAtURL:rootURL
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error],
              @"Error: %@", error);
  }

  self.storage = [[GULHeartbeatDateStorage alloc] initWithFileName:kTestFileName];

  [self assertInitializationDoesNotAccessFileSystem];
}
#endif  // TARGET_OS_TV

- (void)tearDown {
#if TARGET_OS_TV
  [self.defaults removePersistentDomainForName:[self userDefaultsSuiteName]];
  self.defaults = nil;
#else
  [[NSFileManager defaultManager] removeItemAtURL:[self.storage fileURL] error:nil];
#endif  // TARGET_OS_TV
  self.storage = nil;
}

- (void)testHeartbeatDateForTag {
  NSDate *now = [NSDate date];
  [self.storage setHearbeatDate:now forTag:@"fire-iid"];
  XCTAssertEqual([now timeIntervalSinceReferenceDate],
                 [[self.storage heartbeatDateForTag:@"fire-iid"] timeIntervalSinceReferenceDate]);
}

#pragma mark - Private Helpers

#if TARGET_OS_TV

- (NSString *)userDefaultsSuiteName {
  NSCharacterSet *lettersToTrim = [[NSCharacterSet letterCharacterSet] invertedSet];
  NSString *nameWithSpaces = [self.name stringByTrimmingCharactersInSet:lettersToTrim];
  return [nameWithSpaces stringByReplacingOccurrencesOfString:@" " withString:@"_"];
}

#else

- (void)assertInitializationDoesNotAccessFileSystem {
  NSURL *fileURL = [self heartbeatFileURL];
  NSError *error;
  BOOL fileIsReachable = [fileURL checkResourceIsReachableAndReturnError:&error];
  XCTAssertFalse(fileIsReachable,
                 @"GULHeartbeatDateStorage initialization should not access the file system.");
  XCTAssertNotNil(error, @"Error: %@", error);
}

- (NSURL *)heartbeatFileURL {
  NSArray *path =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *rootPath = [path firstObject];
  NSArray<NSString *> *components = @[ rootPath, @"Google/FIRApp", kTestFileName ];
  NSString *fileString = [NSString pathWithComponents:components];
  NSURL *fileURL = [NSURL fileURLWithPath:fileString];
  return fileURL;
}

#endif  // TARGET_OS_TV

@end
