// Copyright 2026 Google LLC
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

#import "GoogleUtilities/Network/GULNetworkInternal.h"
#import "GoogleUtilities/Network/Public/GoogleUtilities/GULNetworkConstants.h"
#import "GoogleUtilities/Network/Public/GoogleUtilities/GULNetworkURLSession.h"

/// A task whose `response` can be set, used to simulate responses delivered by `NSURLSession`.
@interface GULFakeURLSessionTask : NSURLSessionTask
@property(nonatomic, nullable) NSURLResponse *fakeResponse;
@end

@implementation GULFakeURLSessionTask

- (NSURLResponse *)response {
  return self.fakeResponse;
}

@end

/// Tests for how `GULNetworkURLSession` handles the response of a completed task. These tests call
/// the `NSURLSessionTaskDelegate` method directly, so they don't send any network requests.
@interface GULNetworkURLSessionTest : XCTestCase
@end

@implementation GULNetworkURLSessionTest

- (GULFakeURLSessionTask *)taskWithResponse:(nullable NSURLResponse *)response {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  GULFakeURLSessionTask *task = [[GULFakeURLSessionTask alloc] init];
#pragma clang diagnostic pop
  task.fakeResponse = response;
  return task;
}

/// Simulates the completion of `task` and returns the values passed to the completion handler.
- (void)completeTask:(NSURLSessionTask *)task
           withError:(nullable NSError *)error
            response:(NSHTTPURLResponse *_Nullable *_Nonnull)outResponse
               error:(NSError *_Nullable *_Nonnull)outError {
  GULNetworkURLSession *fetcher = [[GULNetworkURLSession alloc] initWithNetworkLoggerDelegate:nil];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  __block NSHTTPURLResponse *receivedResponse = nil;
  __block NSError *receivedError = nil;
  GULNetworkURLSessionCompletionHandler handler =
      ^(NSHTTPURLResponse *response, NSData *data, NSString *sessionID, NSError *error) {
        receivedResponse = response;
        receivedError = error;
        [expectation fulfill];
      };
  // The completion handler is normally stored when a request is sent.
  [fetcher setValue:handler forKey:@"completionHandler"];

  NSURLSession *session = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
  [(id<NSURLSessionTaskDelegate>)fetcher URLSession:session task:task didCompleteWithError:error];

  [self waitForExpectations:@[ expectation ] timeout:5];
  *outResponse = receivedResponse;
  *outError = receivedError;
}

- (void)testHTTPResponseIsPassedThrough {
  NSURL *URL = [NSURL URLWithString:@"https://google.com"];
  NSHTTPURLResponse *HTTPResponse = [[NSHTTPURLResponse alloc] initWithURL:URL
                                                                statusCode:200
                                                               HTTPVersion:@"HTTP/1.1"
                                                              headerFields:nil];
  NSError *systemError = [NSError errorWithDomain:NSURLErrorDomain code:-1 userInfo:nil];

  NSHTTPURLResponse *response;
  NSError *error;
  [self completeTask:[self taskWithResponse:HTTPResponse]
           withError:systemError
            response:&response
               error:&error];

  XCTAssertEqual(response, HTTPResponse);
  // The server responded, so the system error is ignored.
  XCTAssertNil(error);
}

- (void)testNonHTTPResponseReturnsError {
  NSURL *URL = [NSURL URLWithString:@"https://google.com"];
  NSURLResponse *nonHTTPResponse = [[NSURLResponse alloc] initWithURL:URL
                                                             MIMEType:@"text/plain"
                                                expectedContentLength:0
                                                     textEncodingName:nil];

  NSHTTPURLResponse *response;
  NSError *error;
  [self completeTask:[self taskWithResponse:nonHTTPResponse]
           withError:nil
            response:&response
               error:&error];

  // A non-HTTP response must not be passed to callers as an `NSHTTPURLResponse`.
  XCTAssertNil(response);
  XCTAssertEqualObjects(error.domain, kGULNetworkErrorDomain);
  XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidResponse);
}

- (void)testMissingResponseReturnsError {
  NSHTTPURLResponse *response;
  NSError *error;
  [self completeTask:[self taskWithResponse:nil] withError:nil response:&response error:&error];

  XCTAssertNil(response);
  XCTAssertEqualObjects(error.domain, kGULNetworkErrorDomain);
  XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidResponse);
}

- (void)testMissingResponsePassesSystemError {
  NSError *systemError = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorNotConnectedToInternet
                                         userInfo:nil];

  NSHTTPURLResponse *response;
  NSError *error;
  [self completeTask:[self taskWithResponse:nil]
           withError:systemError
            response:&response
               error:&error];

  XCTAssertNil(response);
  XCTAssertEqualObjects(error, systemError);
}

@end
