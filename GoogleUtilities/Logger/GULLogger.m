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

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULLogger.h"

#import <OSLog/OSLog.h>

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULAppEnvironmentUtil.h"
#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULLoggerLevel.h"

/// ASL client facility name used by GULLogger.
const char *kGULLoggerASLClientFacilityName = "com.google.utilities.logger";

static dispatch_once_t sGULLoggerOnceToken;

static os_log_t sLogObject;

static dispatch_queue_t sGULClientQueue;

static BOOL sGULLoggerDebugMode;

static GULLoggerLevel sGULLoggerMaximumLevel;

// Allow clients to register a version to include in the log.
static NSString *sVersion = @"";

static GULLoggerService kGULLoggerLogger = @"[GULLogger]";

#ifdef DEBUG
/// The regex pattern for the message code.
static NSString *const kMessageCodePattern = @"^I-[A-Z]{3}[0-9]{6}$";
static NSRegularExpression *sMessageCodeRegex;
#endif

void GULLoggerInitializeASL(void) {
  dispatch_once(&sGULLoggerOnceToken, ^{
    // Initialize the OSLog custom object
    sLogObject = os_log_create(kGULLoggerASLClientFacilityName, "GULLogger");
    sGULLoggerMaximumLevel = GULLoggerLevelNotice;

    sGULClientQueue = dispatch_queue_create("GULLoggingClientQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(sGULClientQueue,
                              dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
#ifdef DEBUG
    sMessageCodeRegex = [NSRegularExpression regularExpressionWithPattern:kMessageCodePattern
                                                                  options:0
                                                                    error:NULL];
#endif
  });
}

void GULLoggerEnableSTDERR(void) {
}

void GULLoggerForceDebug(void) {
  // We should enable debug mode if we're not running from App Store.
  if (![GULAppEnvironmentUtil isFromAppStore]) {
    sGULLoggerDebugMode = YES;
    GULSetLoggerLevel(GULLoggerLevelDebug);
  }
}

GULLoggerLevel GULGetLoggerLevel(void) {
  return sGULLoggerMaximumLevel;
}

__attribute__((no_sanitize("thread"))) void GULSetLoggerLevel(GULLoggerLevel loggerLevel) {
  if (loggerLevel < GULLoggerLevelMin || loggerLevel > GULLoggerLevelMax) {
    GULLogError(kGULLoggerLogger, NO, @"I-COR000023", @"Invalid logger level, %ld",
                (long)loggerLevel);
    return;
  }
  GULLoggerInitializeASL();
  // We should not raise the logger level if we are running from App Store.
  if (loggerLevel >= GULLoggerLevelNotice && [GULAppEnvironmentUtil isFromAppStore]) {
    return;
  }

  sGULLoggerMaximumLevel = loggerLevel;
}

/**
 * Check if the level is high enough to be loggable.
 */
__attribute__((no_sanitize("thread"))) BOOL GULIsLoggableLevel(GULLoggerLevel loggerLevel) {
  GULLoggerInitializeASL();
  if (sGULLoggerDebugMode) {
    return YES;
  }
  return (BOOL)(loggerLevel <= sGULLoggerMaximumLevel);
}

#ifdef DEBUG
void GULResetLogger(void) {
  sGULLoggerOnceToken = 0;
  sGULLoggerDebugMode = NO;
  sGULLoggerMaximumLevel = GULLoggerLevelNotice;
}

void* getGULLoggerClient(void) {
  return nil;
}

dispatch_queue_t getGULClientQueue(void) {
  return sGULClientQueue;
}

BOOL getGULLoggerDebugMode(void) {
  return sGULLoggerDebugMode;
}
#endif

void GULLoggerRegisterVersion(NSString *version) {
  sVersion = version;
}

os_log_type_t convertLoggerLevel(GULLoggerLevel level) {
    switch (level) {
        case GULLoggerLevelDebug:
            return OS_LOG_TYPE_DEBUG;
        case GULLoggerLevelInfo:
            return OS_LOG_TYPE_INFO;
        case GULLoggerLevelNotice:
            return OS_LOG_TYPE_DEFAULT;
        case GULLoggerLevelWarning:
            return OS_LOG_TYPE_DEFAULT;
        case GULLoggerLevelError:
            return OS_LOG_TYPE_ERROR;
        default:
            return OS_LOG_TYPE_DEFAULT;
    }
}

void GULLogBasic(GULLoggerLevel level,
                 GULLoggerService service,
                 BOOL forceLog,
                 NSString *messageCode,
                 NSString *message,
                 va_list args_ptr) {
  GULLoggerInitializeASL();
  if (!(level <= sGULLoggerMaximumLevel || sGULLoggerDebugMode || forceLog)) {
    return;
  }

#ifdef DEBUG
  NSCAssert(messageCode.length == 11, @"Incorrect message code length.");
  NSRange messageCodeRange = NSMakeRange(0, messageCode.length);
  NSUInteger __unused numberOfMatches =
      [sMessageCodeRegex numberOfMatchesInString:messageCode options:0 range:messageCodeRange];
  NSCAssert(numberOfMatches == 1, @"Incorrect message code format.");
#endif
  NSString *logMsg;
  if (args_ptr == NULL) {
    logMsg = message;
  } else {
    logMsg = [[NSString alloc] initWithFormat:message arguments:args_ptr];
  }
  logMsg = [NSString stringWithFormat:@"%@ - %@[%@] %@", sVersion, service, messageCode, logMsg];
  dispatch_async(sGULClientQueue, ^{
    os_log_with_type(sLogObject, convertLoggerLevel(level), "%{public}@", logMsg);
  });
}

/**
 * Generates the logging functions using macros.
 *
 * Calling GULLogError({service}, @"I-XYZ000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [{service}][I-XYZ000001] Configure blah failed.
 * Calling GULLogDebug({service}, @"I-XYZ000001", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [{service}][I-XYZ000001] Configure succeed.
 */
#define GUL_LOGGING_FUNCTION(level)                                                     \
  void GULLog##level(GULLoggerService service, BOOL force, NSString *messageCode,       \
                     NSString *message, ...) {                                          \
    va_list args_ptr;                                                                   \
    va_start(args_ptr, message);                                                        \
    GULLogBasic(GULLoggerLevel##level, service, force, messageCode, message, args_ptr); \
    va_end(args_ptr);                                                                   \
  }

GUL_LOGGING_FUNCTION(Error)
GUL_LOGGING_FUNCTION(Warning)
GUL_LOGGING_FUNCTION(Notice)
GUL_LOGGING_FUNCTION(Info)
GUL_LOGGING_FUNCTION(Debug)

#undef GUL_MAKE_LOGGER

#pragma mark - GULLoggerWrapper

@implementation GULLoggerWrapper

+ (void)logWithLevel:(GULLoggerLevel)level
         withService:(GULLoggerService)service
            withCode:(NSString *)messageCode
         withMessage:(NSString *)message
            withArgs:(va_list)args {
  GULLogBasic(level, service, NO, messageCode, message, args);
}

@end
