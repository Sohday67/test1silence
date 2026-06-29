//
//  SSSmartSpeedController.h
//  SkipSilenceYT
//
//  Drives AVPlayer's `rate` based on SSSilenceDetector decisions.
//  Mirrors Overcast's behavior: during silent regions, bump playback
//  to `silenceSkippingSpeed` (default 1.5x). When speech resumes,
//  restore the user's preferred rate. This is the same trick Overcast
//  uses so it doesn't have to physically cut audio buffers — the
//  streaming pipeline is left intact and the rate change is cheap.
//
//  Smart Speed savings (seconds skipped) are accumulated and reported
//  in the YTLite settings panel exactly like Overcast's
//  "Smart Speed saved X of Y seconds (Z%)".
//

#ifndef SS_SMART_SPEED_CONTROLLER_H
#define SS_SMART_SPEED_CONTROLLER_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SSAudioTap.h"

NS_ASSUME_NONNULL_BEGIN

@interface SSSmartSpeedController : NSObject <SSAudioTapDelegate>

@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, strong) SSAudioTap *tap;

// User-configurable base playback rate (typically 1.0x).
@property (nonatomic, assign) float userRate;
// Rate applied during silent regions (Overcast's `silenceSkippingSpeed`).
@property (nonatomic, assign) float silenceSkippingSpeed;
// Minimum silence duration before we engage the skip rate.
@property (nonatomic, assign) NSTimeInterval minimumSilenceDurationToSkip;
// Whether Smart Speed is armed (master toggle).
@property (nonatomic, assign) BOOL enabled;

// Lifetime stats (persisted via NSUserDefaults by SSPrefs).
@property (nonatomic, readonly) NSTimeInterval totalSavedSeconds;
@property (nonatomic, readonly) NSTimeInterval totalPlayedSeconds;

- (instancetype)initWithPlayer:(AVPlayer *)player;
- (void)start;
- (void)stop;
- (void)resetStats;
- (NSDictionary<NSString *, NSNumber *> *)statsDictionary;

@end

NS_ASSUME_NONNULL_END

#endif /* SS_SMART_SPEED_CONTROLLER_H */
