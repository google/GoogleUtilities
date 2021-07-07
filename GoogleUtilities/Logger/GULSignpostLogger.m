//
//  GULSignpostLogger.m
//  GoogleUtilities
//
//  Created by Maksym Malyhin on 2021-07-07.
//

#import "GULSignpostLogger.h"

gul_os_log_t _gul_default_signpost_log(void) {
  static gul_os_log_t _default_signpost_log;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _default_signpost_log = os_log_create("com.GoogleUtilities.signpost", "signpost")
  });
  return _default_signpost_log;
}
