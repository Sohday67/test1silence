//
//  SSAudioTap.h
//  SkipSilenceYT
//
//  Real-time PCM tap installed on AVPlayerItem's first audio track.
//  Mirrors the role of Overcast's `OCAudioStreamer` render callback,
//  but uses the public MTAudioProcessingTap API so it works inside
//  YouTube's AVPlayer-based player.
//

#ifndef SS_AUDIO_TAP_H
#define SS_AUDIO_TAP_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaToolbox/MediaToolbox.h>
#import "SSSilenceDetector.h"

NS_ASSUME_NONNULL_BEGIN

@class SSAudioTap;

@protocol SSAudioTapDelegate <NSObject>
@optional
// Called from the audio thread whenever a new LUFS measurement is finalized.
- (void)audioTap:(SSAudioTap *)tap
   didMeasureLUFS:(float)lufs
       isSilent:(BOOL)isSilent
  silenceDuration:(NSTimeInterval)duration;
@end

@interface SSAudioTap : NSObject

@property (nonatomic, weak) id<SSAudioTapDelegate> delegate;
@property (nonatomic, strong, readonly) SSSilenceDetector *detector;
@property (nonatomic, readonly) BOOL isInstalled;

- (BOOL)installOnPlayerItem:(AVPlayerItem *)item error:(NSError **)error;
- (void)uninstall;

// Reconfigure the detector after the user changes settings.
- (void)reconfigureWithSampleRate:(double)sr
                          channels:(NSUInteger)ch
               loudnessTargetLUFS:(float)threshold
           minimumSilenceDuration:(NSTimeInterval)duration
            musicDetectionBypass:(BOOL)bypass;

@end

NS_ASSUME_NONNULL_END

#endif /* SS_AUDIO_TAP_H */
