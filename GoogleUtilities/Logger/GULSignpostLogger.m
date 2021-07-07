//
//  GULSignpostLogger.m
//  GoogleUtilities
//
//  Created by Maksym Malyhin on 2021-07-07.
//

#import <Foundation/Foundation.h>

#import "GoogleUtilities/Logger/Public/GoogleUtilities/GULSignpostLogger.h"

gul_os_log_t _gul_default_signpost_log(void) {
  static gul_os_log_t _default_signpost_log;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _default_signpost_log = os_log_create("com.GoogleUtilities.signpost", "signpost");
  });
  return _default_signpost_log;
}

void _gul_os_signpost_interval_begin(gul_os_log_t log, gul_os_signpost_id_t interval_id, const char *name, ...) {
  if (@available(iOS 12.0, *)) {
    os_signpost_interval_begin(log, interval_id, name, "" __VA_ARGS__);
  } else {
    // Fallback on earlier versions
  }
}
