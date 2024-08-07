// Copyright 2018 Google
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

#ifdef DEBUG
// The tests depend upon library methods only built with #ifdef DEBUG

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULLogger.h"

#import <asl.h>
#import <os/log.h>

extern void GULResetLogger(void);

extern dispatch_queue_t getGULClientQueue(void);

extern BOOL getGULLoggerDebugMode(void);

extern os_log_type_t GULLoggerLevelToOSLogType(GULLoggerLevel level);

static NSString *const kMessageCode = @"I-COR000001";

@interface GULLoggerTest : XCTestCase

@property(nonatomic) NSString *randomLogString;

@property(nonatomic, strong) NSUserDefaults *defaults;

@end

@implementation GULLoggerTest

+ (void)setUp {
  GULLoggerInitialize();
}

- (void)setUp {
  [super setUp];
  GULResetLogger();

  // Stub NSUserDefaults for cleaner testing.
  _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.google.logger_test"];
}

- (void)tearDown {
  [super tearDown];

  _defaults = nil;
}

- (void)testMessageCodeFormat {
  // Valid case.
  XCTAssertNoThrow(
      GULOSLogError(@"com.my.service", @"My/Category", NO, @"I-APP000001", @"Message."));

  // An extra dash or missing dash should fail.
  XCTAssertThrows(
      GULOSLogError(@"com.my.service", @"My/Category", NO, @"I-APP-000001", @"Message."));
  XCTAssertThrows(GULOSLogError(@"com.my.service", @"My/Category", NO, @"IAPP000001", @"Message."));

  // Wrong number of digits should fail.
  XCTAssertThrows(GULOSLogError(@"com.my.service", @"My/Category", NO, @"I-APP00001", @"Message."));
  XCTAssertThrows(
      GULOSLogError(@"com.my.service", @"My/Category", NO, @"I-APP0000001", @"Message."));

  // Lowercase should fail.
  XCTAssertThrows(
      GULOSLogError(@"com.my.service", @"My/Category", NO, @"I-app000001", @"Message."));

// nil or empty message code should fail.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows(GULOSLogError(@"com.my.service", @"My/Category", NO, nil, @"Message."));
#pragma clang diagnostic pop

  XCTAssertThrows(GULOSLogError(@"com.my.service", @"My/Category", NO, @"", @"Message."));

  // Android message code should fail.
  XCTAssertThrows(
      GULOSLogError(@"com.my.service", @"My/Category", NO, @"A-APP000001", @"Message."));
}

// The GULLoggerLevel enum must match the ASL_LEVEL_* constants, but we manually redefine
// them in GULLoggerLevel.h since we cannot include <asl.h> (see b/34976089 for more details).
// This test ensures the constants match.
- (void)testGULLoggerLevelValues {
  XCTAssertEqual(GULLoggerLevelError, ASL_LEVEL_ERR);
  XCTAssertEqual(GULLoggerLevelWarning, ASL_LEVEL_WARNING);
  XCTAssertEqual(GULLoggerLevelNotice, ASL_LEVEL_NOTICE);
  XCTAssertEqual(GULLoggerLevelInfo, ASL_LEVEL_INFO);
  XCTAssertEqual(GULLoggerLevelDebug, ASL_LEVEL_DEBUG);
}

- (void)testGULLoggerLevelToOSLogType {
  XCTAssertEqual(GULLoggerLevelToOSLogType(GULLoggerLevelError), OS_LOG_TYPE_ERROR);
  // OSLog doesn't have a WARNING level so it is remapped to DEFAULT (Notice).
  XCTAssertEqual(GULLoggerLevelToOSLogType(GULLoggerLevelWarning),
                 GULLoggerLevelToOSLogType(GULLoggerLevelNotice));
  XCTAssertEqual(GULLoggerLevelToOSLogType(GULLoggerLevelNotice), OS_LOG_TYPE_DEFAULT);
  XCTAssertEqual(GULLoggerLevelToOSLogType(GULLoggerLevelInfo), OS_LOG_TYPE_INFO);
  XCTAssertEqual(GULLoggerLevelToOSLogType(GULLoggerLevelDebug), OS_LOG_TYPE_DEBUG);
}

- (void)testGULGetLoggerLevel {
  GULLoggerLevel loggerLevel = GULGetLoggerLevel();

  // The default logger level is GULLoggerLevelNotice.
  XCTAssertEqual(loggerLevel, GULLoggerLevelNotice);
}

- (void)testGULSetLoggerLevel {
  GULSetLoggerLevel(GULLoggerLevelDebug);

  GULLoggerLevel loggerLevel = GULGetLoggerLevel();

  // The default logger level is GULLoggerLevelNotice.
  XCTAssertEqual(loggerLevel, GULLoggerLevelDebug);
}

- (void)testGULResetLogger_ResetsLoggerLevel {
  GULSetLoggerLevel(GULLoggerLevelDebug);

  GULResetLogger();
  GULLoggerLevel loggerLevel = GULGetLoggerLevel();

  // The default logger level is GULLoggerLevelNotice.
  XCTAssertEqual(loggerLevel, GULLoggerLevelNotice);
}

@end
#endif
