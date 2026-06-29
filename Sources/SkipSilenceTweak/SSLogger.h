//
//  SSLogger.h
//  SkipSilenceYT
//
//  Lightweight NSLog wrapper that respects a debug flag in NSUserDefaults.
//

#ifndef SS_LOGGER_H
#define SS_LOGGER_H

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define SSLog(fmt, ...) NSLog(@"[SkipSilenceYT] " fmt, ##__VA_ARGS__)
#else
#define SSLog(fmt, ...) do { \
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ssDebugLogging"]) { \
        NSLog(@"[SkipSilenceYT] " fmt, ##__VA_ARGS__); \
    } \
} while (0)
#endif

#endif /* SS_LOGGER_H */
