/*
 * Copyright 2020 Google LLC
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

#import "FBLPromise+Testing.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULURLSessionDataResponse.h"
#import "GoogleUtilities/Environment/Public/GoogleUtilities/NSURLSession+GULPromises.h"

@interface NSURLSession_GULPromisesTests : XCTestCase
@property(nonatomic) NSURLSession *URLSession;
@end

@implementation NSURLSession_GULPromisesTests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
}

- (void)testDataTaskPromiseWithRequestSuccess {
  // Given
  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"success.txt"];
  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
  NSData *expectedData = [@"Hello, world!" dataUsingEncoding:NSUTF8StringEncoding];
  BOOL success = [[NSFileManager defaultManager] createFileAtPath:tempPath
                                                         contents:expectedData
                                                       attributes:nil];
  XCTAssert(success);

  // When
  NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
  NSURLRequest *request = [NSURLRequest requestWithURL:tempURL];
  __auto_type taskPromise = [self.URLSession gul_dataTaskPromiseWithRequest:request];

  // Then
  XCTAssert(FBLWaitForPromisesWithTimeout(1.0));
  XCTAssert(taskPromise.isFulfilled);
  XCTAssertNil(taskPromise.error);
  XCTAssertEqualObjects(expectedData, taskPromise.value.HTTPBody);
  XCTAssertEqual(taskPromise.value.HTTPResponse.statusCode, 200);
}

- (void)testDataTaskPromiseWithRequestError {
  // Given
  NSString *tempPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"does_not_exist.txt"];
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:tempPath]);

  // When
  NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
  NSURLRequest *request = [NSURLRequest requestWithURL:tempURL];
  __auto_type taskPromise = [self.URLSession gul_dataTaskPromiseWithRequest:request];

  // Then
  XCTAssert(FBLWaitForPromisesWithTimeout(1.0));
  XCTAssert(taskPromise.isRejected);
  XCTAssertNotNil(taskPromise.error);
  XCTAssertNil(taskPromise.value.HTTPBody);
  XCTAssertEqual(taskPromise.value.HTTPResponse.statusCode, 0);
}

@end
