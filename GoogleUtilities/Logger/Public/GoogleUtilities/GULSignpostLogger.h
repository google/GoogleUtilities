//
//  GULSignpostLogger.h
//  GoogleUtilities
//
//  Created by Maksym Malyhin on 2021-07-07.
//

// Wrapper that allows using signpost (<os/signpost.h>) API when available and do nothing when it's not. It is introduced to reduce availability checks on the client side.

#if __has_include(<os/signpost.h>)
#import <os/signpost.h>

typedef os_log_t gul_os_log_t;
typedef os_signpost_id_t gul_os_signpost_id_t;

// See `os_signpost_interval_begin`.
#define gul_os_signpost_interval_begin(log, interval_id, name, ...) \
    __extension__({ \
        if (@available(iOS 12.0, *)) { \
          os_signpost_interval_begin(log, interval_id, name, "" __VA_ARGS__); \
        } \
    })

// See `os_signpost_interval_end`.
#define gul_os_signpost_interval_end(log, interval_id, name, ...) \
    __extension__({ \
        if (@available(iOS 12.0, *)) { \
          os_signpost_interval_end(log, interval_id, name, "" __VA_ARGS__); \
        } \
    })

// See `os_signpost_interval_end`.
#define gul_os_signpost_interval_emit(log, event_id, name, ...) \
    __extension__({ \
        if (@available(iOS 12.0, *)) { \
          os_signpost_interval_end(log, event_id, name, "" __VA_ARGS__); \
        } \
    })

// See `_gul_default_signpost_log`.
#define gul_default_signpost_log() \
  _gul_default_signpost_log()


#define _gul_os_signpost_interval_begin(log, interval_id, name, ...) \
    __extension__({ \
        if (@available(iOS 12.0, *)) { \
          os_signpost_interval_begin(log, interval_id, name, "" __VA_ARGS__); \
        } \
    })

#else // __has_include(<os/signpost.h>)

// Placeholders for the signpost API methods and types when it's not available.

typedef void gul_os_log_t;
typedef uint64_t gul_os_signpost_id_t;

#define gul_os_signpost_interval_begin(log, interval_id, name, ...)

#define gul_os_signpost_interval_end(log, interval_id, name, ...)

#define gul_os_signpost_interval_emit(log, event_id, name, ...)

#define gul_default_signpost_log()

#endif // __has_include(<os/signpost.h>)

/// Returns a default instance of `gul_os_log_t` to be used for signpost logging when available.
/// @return A default instance of `gul_os_log_t`.
gul_os_log_t _gul_default_signpost_log(void);

// See `os_signpost_id_generate`.
gul_os_signpost_id_t gul_os_signpost_id_generate(gul_os_log_t log);
