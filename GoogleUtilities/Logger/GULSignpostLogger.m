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

gul_os_signpost_id_t gul_os_signpost_id_generate(gul_os_log_t log) {
#if __has_include(<os/signpost.h>)
  if (@available(iOS 12.0, *)) {
    return os_signpost_id_generate(log);
  } else {
    return 0;
  }
#else // __has_include(<os/signpost.h>)
  return 0;
#endif // __has_include(<os/signpost.h>)
}
