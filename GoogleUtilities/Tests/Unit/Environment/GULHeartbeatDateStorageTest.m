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

// Import specific version implementations for compatibility testing.
#import "GoogleUtilities/Tests/Unit/Environment/Sources/GULHeartbeatDateStorageV7.3.1.h"
#import "GoogleUtilities/Tests/Unit/Environment/Sources/GULHeartbeatDateStorageV7.4.0.h"

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

  // Clean up before the test in case the cleanup was not completed in previous tests for some
  // reason (e.g. a crash).
  [self cleanupStorageDir];

  self.storage = [[GULHeartbeatDateStorage alloc] initWithFileName:kTestFileName];
  [self assertInitializationDoesNotAccessFileSystem];
}

- (void)tearDown {
  [super tearDown];

  [self cleanupStorageDir];

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

- (void)testHeartbeatDateForTagWhenHeartbeatFileContainsUnexpectedContent {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with unexpected content.
  NSArray *array = @[ [NSDate distantPast], [NSDate date], [NSDate distantFuture] ];
  NSError *archiveError;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:array error:&archiveError];
  XCTAssertNotNil(data);
  XCTAssert(data.length > 0);
  XCTAssertNil(archiveError);
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [data writeToURL:heartbeatStorageFileURL atomically:YES];

  // 3. Retrieve saved heartbeat info and assert that it is nil.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:@"tag"];
  XCTAssertNil(retrievedDate);
}

- (void)testSetHeartbeatDateForTagWhenHeartbeatFileContainsUnexpectedDictionaryContent {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with unexpected content.
  NSDictionary *heartbeatDict = @{@"tag" : [NSDate distantPast]};
  NSDictionary *nestedHeartbeatDict = @{@"tag" : heartbeatDict};
  NSError *archiveError;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:nestedHeartbeatDict
                                                       error:&archiveError];
  XCTAssertNotNil(data);
  XCTAssert(data.length > 0);
  XCTAssertNil(archiveError);

  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [data writeToURL:heartbeatStorageFileURL atomically:YES];

  // 3. Create heartbeat info.
  NSDate *date = [NSDate date];
  NSString *tag = @"tag";

  // 4. Retrieve heartbeat info that is not stored and assert the retrieved info is nil.
  //    This assertion implies type validation in `heartbeatDateForTag:` has worked correctly.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertNil(retrievedDate);

  // 5. Save the heartbeat info and assert the save was successful.
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);

  // 6. Retrieve heartbeat info that is now stored and assert the retrieved info is accurate.
  retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertEqualObjects(retrievedDate, date);
}

- (void)testSetHeartbeatDateForTagWhenHeartbeatFileContainsUnexpectedContent {
  // 1. Manually create the heartbeat directory.
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSError *error;
  BOOL directoryCreated = [self explicitlyCreateDirectoryForURL:heartbeatStorageDirectoryURL
                                                      withError:&error];
  XCTAssert(directoryCreated);

  // 2. Populate the storage file with unexpected content.
  NSArray *array = @[ [NSDate distantPast], [NSDate date], [NSDate distantFuture] ];
  NSError *archiveError;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:array error:&archiveError];
  XCTAssertNotNil(data);
  XCTAssert(data.length > 0);
  XCTAssertNil(archiveError);

  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  [data writeToURL:heartbeatStorageFileURL atomically:YES];

  // 3. Create heartbeat info.
  NSDate *date = [NSDate date];
  NSString *tag = @"tag";

  // 4. Retrieve heartbeat info that is not stored and assert the retrieved info is nil.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertNil(retrievedDate);

  // 5. Save the heartbeat info and assert the save was successful.
  BOOL successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);

  // 6. Retrieve heartbeat info that is now stored and assert the retrieved info is accurate.
  retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertEqualObjects(retrievedDate, date);
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

- (void)testConformsToHeartbeatStorableProtocol {
  XCTAssertTrue([self.storage conformsToProtocol:@protocol(GULHeartbeatDateStorable)]);
}

#pragma mark - Concurrency tests

- (void)testConcurrentReadWriteWithSingleInstance {
  dispatch_queue_t concurrentQueue = dispatch_queue_create(
      "testConcurrentReadWriteToTheSameFileFromDifferentInstances", DISPATCH_QUEUE_CONCURRENT);

  NSUInteger attemptsCount = 50;

  for (NSUInteger i = 0; i < attemptsCount; i++) {
    dispatch_async(concurrentQueue, ^{
      [self assertWriteAndReadNoFileCorruption:self.storage];
    });
  }

  // Wait until all storage operations completed.
  dispatch_barrier_sync(concurrentQueue, ^{
                        });
}

- (void)testConcurrentReadWritesToTheSameFileFromDifferentInstances {
  dispatch_queue_t concurrentQueue = dispatch_queue_create(
      "testConcurrentReadWriteToTheSameFileFromDifferentInstances", DISPATCH_QUEUE_CONCURRENT);

  GULHeartbeatDateStorage *storage1 =
      [[GULHeartbeatDateStorage alloc] initWithFileName:kTestFileName];
  GULHeartbeatDateStorage *storage2 =
      [[GULHeartbeatDateStorage alloc] initWithFileName:kTestFileName];

  NSUInteger attemptsCount = 50;

  for (NSUInteger i = 0; i < attemptsCount; i++) {
    dispatch_async(concurrentQueue, ^{
      [self assertWriteAndReadNoFileCorruption:storage1];
    });
  }

  for (NSUInteger i = 0; i < attemptsCount; i++) {
    dispatch_async(concurrentQueue, ^{
      [self assertWriteAndReadNoFileCorruption:storage2];
    });
  }

  // Wait until all storage operations completed.
  dispatch_barrier_sync(concurrentQueue, ^{
                        });
}

#pragma mark - Version Compatibility (#36)

- (void)testCompatibility_pre7_4_0 {
  NSString *tag = @"tag";

  // 1. Store heartbeat using current heartbeat API.
  NSDate *distantPast = [NSDate distantPast];
  BOOL successfulSave = [self.storage setHearbeatDate:distantPast forTag:tag];
  XCTAssert(successfulSave);
  [self assertStoredHeartbeatDictionaryIsKindOf:[NSMutableDictionary class]];

  // 2. Developer downgrades to below 7.4.0.

  // 3. Store heartbeat from pre-7.4.0 API and verify success.
  NSDate *storedDate = [NSDate date];
  GULHeartbeatDateStorage7_3_1 *storage7_3_1 =
      [[GULHeartbeatDateStorage7_3_1 alloc] initWithFileName:kTestFileName];
  // The following line caused crashes after persistent storage modifications by 7.4.0.
  successfulSave = [storage7_3_1 setHearbeatDate:storedDate forTag:tag];
  XCTAssert(successfulSave);
  [self assertStoredHeartbeatDictionaryIsKindOf:[NSMutableDictionary class]];

  NSDate *retrievedDate = [storage7_3_1 heartbeatDateForTag:tag];
  XCTAssertEqualObjects(retrievedDate, storedDate);
}

- (void)testForwardCompatibility7_4_0 {
  NSString *tag = @"tag";

  // 1. Store heartbeat using heartbeat API from 7.4.0. (Immutable info is written to disk.)
  NSDate *storedDate = [NSDate distantPast];
  GULHeartbeatDateStorage7_4_0 *storage7_4_0 =
      [[GULHeartbeatDateStorage7_4_0 alloc] initWithFileName:kTestFileName];
  // The following line caused crashes after persistent storage modifications by 7.4.0.
  BOOL successfulSave = [storage7_4_0 setHearbeatDate:storedDate forTag:tag];
  XCTAssert(successfulSave);
  [self assertStoredHeartbeatDictionaryIsKindOf:[NSDictionary class]];

  // 2. Developer upgrades to current version.

  // 3. Retrieve and then store heartbeat from current API and verify success.
  NSDate *retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertNotNil(retrievedDate);
  XCTAssertEqualObjects(retrievedDate, storedDate);

  NSDate *date = [NSDate date];
  successfulSave = [self.storage setHearbeatDate:date forTag:tag];
  XCTAssert(successfulSave);
  [self assertStoredHeartbeatDictionaryIsKindOf:[NSMutableDictionary class]];

  retrievedDate = [self.storage heartbeatDateForTag:tag];
  XCTAssertNotNil(retrievedDate);
  XCTAssertEqualObjects(retrievedDate, date);
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

- (void)assertStoredHeartbeatDictionaryIsKindOf:(Class)class {
  NSURL *heartbeatStorageDirectoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  NSURL *heartbeatStorageFileURL = [self fileURLForDirectory:heartbeatStorageDirectoryURL];
  NSData *objectData = [NSData dataWithContentsOfURL:heartbeatStorageFileURL options:0 error:nil];
  __auto_type objectClasses =
      [NSSet setWithArray:@[ NSDictionary.class, NSDate.class, NSString.class ]];
  NSMutableDictionary *heartbeatDict = [GULSecureCoding unarchivedObjectOfClasses:objectClasses
                                                                         fromData:objectData
                                                                            error:nil];
  if (class == [NSDictionary class]) {
    XCTAssertFalse([heartbeatDict isKindOfClass:[NSMutableDictionary class]]);
  }
  XCTAssertTrue([heartbeatDict isKindOfClass:class]);
}

- (void)assertWriteAndReadNoFileCorruption:(GULHeartbeatDateStorage *)storage {
  NSString *tag = self.name;
  NSDate *date = [NSDate date];
  [storage setHearbeatDate:date forTag:tag];

  // Assert that the file was not corrupted by concurrent access.
  // NOTE: With the current synchronization model we cannot expect the read date to be equal the
  // date just set because another date may be set from another thread before read is performed.
  // Prevent the read/modify/write data race is currently the storage clients responsibility.
  XCTAssertNotNil([storage heartbeatDateForTag:tag]);
}

- (void)cleanupStorageDir {
  // Removes the Heartbeat Storage Directory if it exists.
  NSURL *directoryURL = [self pathURLForDirectory:kGULHeartbeatStorageDirectory];
  [[NSFileManager defaultManager] removeItemAtURL:directoryURL error:nil];
}

@end
