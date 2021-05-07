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
#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULSecureCoding.h"

@interface GULHeartbeatDateStorageTest : XCTestCase
@property(nonatomic) GULHeartbeatDateStorage *storage;
@end

static NSString *const kTestFileName = @"GULStorageHeartbeatTestFile";

@implementation GULHeartbeatDateStorageTest {
  BOOL _rootDirectoryCreated;
}

- (BOOL)setUpWithError:(NSError *__autoreleasing _Nullable *)error {
  [super setUpWithError:error];

  NSError *directoryError;
  if (!_rootDirectoryCreated) {
    _rootDirectoryCreated = [self createRootDirectoryWithError:&directoryError];
  }

  BOOL success = _rootDirectoryCreated;
  if (!success && error) {
    *error = [NSError errorWithDomain:@"com.GULHeartbeatDateStorageTest.ErrorDomain"
                                 code:1
                             userInfo:@{NSUnderlyingErrorKey : directoryError}];
  }

  return success;
}

- (void)setUp {
  [super setUp];

  self.storage = [[GULHeartbeatDateStorage alloc] initWithFileName:kTestFileName];
  [self assertInitializationDoesNotAccessFileSystem];
}

- (void)tearDown {
  [super tearDown];

  // Removes the Heartbeat Storage Directory if it exists.
  NSURL *directoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];

  self.storage = nil;
}

#pragma mark - Public API Tests

- (void)testHeartbeatDateForTag {
  // 1. Tags and saves heartbeat info, which creates the storage directory & file as side effects.
  NSDate *date = [NSDate date];
  NSString *tag = @"tag";
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);

  // 2. Retrieve saved heartbeat info.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];

  // 3. Assert that requested heartbeat info matches what was stored.
  //    This implies the storage directory & file were created, written to, and read from.
  XCTAssertEqualObjects(retrievedDate, date);
}

/// Heartbeat info is requested when the storage directory already exists (i.e. it was created in a
/// previous app launch).
- (void)testHeartbeatDateForTagWhenHeartbeatStorageDirectoryExists {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with heartbeat info.
  // 2.1 Create a dictionary with heartbeat info.
  NSDate *storedDate = [NSDate distantPast];
  NSString *storedTag = @"stored-tag";
  NSDictionary *storedHeartbeatDictionary = @{storedTag : storedDate};
  // 2.2 Encode the dictionary.
  NSError *archiveError;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:storedHeartbeatDictionary
                                                       error:&archiveError];
  XCTAssertNotNil(data);
  XCTAssertNil(archiveError);

  // 2.3 Write the encoded dictionary to file.
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [data writeToURL:heartbeatStorageFileURL atomically:YES];
  XCTAssertNotNil(data);

  // 3. Retrieve the stored heartbeat info and validate that it matches the info that was stored.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:storedTag];

  XCTAssertEqualObjects(retrievedDate, storedDate);
}

- (void)testHeartbeatDateForTagWhenReturnedDateIsNil {
  NSString *nonexistentTag = @"missing-tag";
  NSDate *nilDate = [self.storage heartbeatDateForTag:nonexistentTag];
  XCTAssertNil(nilDate);
}

- (void)testSetHeartbeatDateForTagWhenExpectingFailure {
  // The `setHearbeatDate: forTag:` API is expected to return NO if it is unable to write the
  // heartbeat info to file. To verify the API successfully fails, an invalid string is used to
  // create an invalid instance of `GULHeartbeatDateStorage` by supplying an invalid filename.
  // This replicates a file system error that prohibits `setHearbeatDate: forTag:` from successfully
  // storing the heartbeat info.
  NSString *invalidFileName = @"";
  GULHeartbeatDateStorage *invalidStorage =
      [[GULHeartbeatDateStorage alloc] initWithFileName:invalidFileName];

  BOOL success = [invalidStorage setHearbeatDate:NSDate.date forTag:@"tag"];
  XCTAssertFalse(success);
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

- (void)testHeartbeatDateForTagWhenHeartbeatFileReturnsInvalidData {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with invalid data.
  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNotNil(corruptedData);
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [corruptedData writeToURL:heartbeatStorageFileURL atomically:YES];

  // 3. Retrieve saved heartbeat info and assert that it is nil.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:@"tag"];
  XCTAssertNil(retrievedDate);
}

- (void)testSetHeartbeatDateForTagWhenHeartbeatFileReturnsInvalidData {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with invalid data.
  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNotNil(corruptedData);
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [corruptedData writeToURL:heartbeatStorageFileURL atomically:YES];

  // 3. Tag and save heartbeat info. This should overwrite the invalid data with a
  //    correctly encoded heartbeat dictionary.
  NSDate *date = [NSDate date];
  NSString *tag = @"tag";
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);

  // 4. Retrieve saved heartbeat info.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];

  // 5. Assert that requested heartbeat info matches what was stored.
  //    This implies the storage directory & file were created, written to, and read from.
  XCTAssertEqualObjects(retrievedDate, date);
}

// Ensures that `setHearbeatDate:forTag:` API successfully functions when
// stored heartbeat dictionary is immutable. See GoogleUtilities issue #36 for context.
- (void)testSetHeartbeatDateForTagWhenStoredHeartbeatDictionaryIsImmutable {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with heartbeat info.
  // 2.1 Create an *immutable* dictionary with heartbeat info.
  NSDate *storedDate = [NSDate distantPast];
  NSString *storedTag = @"stored-tag";
  NSDictionary *storedHeartbeatDictionary = @{storedTag : storedDate};
  // 2.2 Encode the dictionary.
  NSError *archiveError;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:storedHeartbeatDictionary
                                                       error:&archiveError];
  XCTAssertNotNil(data);
  XCTAssertNil(archiveError);
  // 2.3 Write the encoded dictionary to file.
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [data writeToURL:heartbeatStorageFileURL atomically:YES];
  XCTAssertNotNil(data);

  // 3. Tag and save new heartbeat date for `storedTag`.
  NSDate *date = [NSDate date];
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:storedTag];
  XCTAssert(successfulSave);

  // 4. Retrieve saved heartbeat info.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:storedTag];

  // 5. Assert that requested heartbeat info matches what was stored.
  //    This implies the storage directory & file were created, written to, and read from.
  XCTAssertEqualObjects(retrievedDate, date);
}

- (void)testConformsToHeartbeatStorableProtocol {
  XCTAssertTrue([self.storage conformsToProtocol:@protocol(GULHeartbeatDateStorable)]);
}

#pragma mark - Testing Utilities

- (BOOL)createRootDirectoryWithError:(NSError *__autoreleasing _Nullable *)outError {
  NSArray<NSString *> *paths;
#if TARGET_OS_TV
  paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
  paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
#endif  // TARGET_OS_TV
  NSString *rootPath = [paths lastObject];
  NSURL *rootURL = [NSURL fileURLWithPath:rootPath];

  BOOL rootDirectoryExists = [rootURL checkResourceIsReachableAndReturnError:nil];
  if (!rootDirectoryExists) {
    rootDirectoryExists = [[NSFileManager defaultManager] createDirectoryAtURL:rootURL
                                                   withIntermediateDirectories:YES
                                                                    attributes:nil
                                                                         error:outError];
  }
  return rootDirectoryExists;
}

- (BOOL)explicitlyCreateDirectoryForURL:(NSURL *)directoryPathURL withError:(NSError **)outError {
  BOOL success = false;
  if (![directoryPathURL checkResourceIsReachableAndReturnError:outError]) {
    success = [[NSFileManager defaultManager] createDirectoryAtURL:directoryPathURL
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:outError];
  }
  return success;
}

- (void)assertInitializationDoesNotAccessFileSystem {
  NSString *directoryURL = [[self pathURLForDirectory:kGULHeartbeatStorageDirectory] path];
  BOOL isDir;
  BOOL directoryIsReachable =
      [[NSFileManager defaultManager] fileExistsAtPath:directoryURL isDirectory:&isDir] && isDir;
  XCTAssertFalse(directoryIsReachable,
                 @"The Heartbeat Storage Directory already exists. "
                 @"GULHeartbeatDateStorage initialization should not access the file system.");
}

- (NSURL *)pathURLForDirectory:(NSString *)directory {
  NSArray<NSString *> *paths;
#if TARGET_OS_TV
  paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
  paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
#endif  // TARGET_OS_TV
  NSString *rootPath = [paths lastObject];
  NSURL *rootURL = [NSURL fileURLWithPath:rootPath];
  NSURL *directoryURL = [rootURL URLByAppendingPathComponent:directory];
  return directoryURL;
}

- (NSURL *)fileURLForDirectory:(NSURL *)directoryURL {
  NSURL *fileURL = [directoryURL URLByAppendingPathComponent:kTestFileName];
  return fileURL;
}

@end
