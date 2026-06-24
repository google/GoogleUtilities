//
//  GULSignpostLoggerTests.m
//  GoogleUtilities-Unit-unit
//
//  Created by Maksym Malyhin on 2021-07-07.
//

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULSignpostLogger.h"

@interface GULSignpostLoggerTests : XCTestCase

@end

@implementation GULSignpostLoggerTests

- (void)testSignpostLogs {
  gul_os_log_t log = gul_default_signpost_log();
  gul_os_signpost_id_t signpostID = gul_os_signpost_id_generate(log);
  gul_os_signpost_interval_begin(log, signpostID, "test begin");
  gul_os_signpost_interval_end(log, signpostID, "test end");
}

@end
