//
//  SSSilenceDetector.h
//  SkipSilenceYT
//
//  Silence detector modeled on Overcast's `OCAudioPlayerCommon` /
//  `OCVoiceBoostLookahead.c`. Implements:
//
//    * ITU-R BS.1770-4 LUFS measurement (delegated to SSLUFS.c)
//    * 2-pass loudness tracking:
//        pass 1: running average LUFS (program loudness)
//        pass 2: short-term peak LUFS (silence reference)
//    * Silence decision: block LUFS < (average - loudnessTargetLUFS)
//    * Minimum-duration gate: a silent region must be longer than
//      `minimumSilenceDuration` (default 0.20 s) to count, mirroring
//      Overcast's `seekToNextSilenceWithMinimumSampleDuration:threshold:`.
//

#ifndef SS_SILENCE_DETECTOR_H
#define SS_SILENCE_DETECTOR_H

#import <Foundation/Foundation.h>
#import "SSLUFS.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SSSilenceDecision) {
    SSSilenceDecisionSpeech = 0,  // current block is speech, normal speed
    SSSilenceDecisionSilence = 1, // current block is silent, skip
    SSSilenceDecisionUndetermined = 2,
};

@interface SSSilenceDetector : NSObject

@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) NSUInteger channelCount;

// In LUFS. Block is silent if its LUFS is more than this many LU below
// the running average (Overcast: `loudnessTargetLUFS`, integer LU).
@property (nonatomic, assign) float loudnessTargetLUFS;

// Absolute silence floor in LUFS (used until the running average is
// stable). -70 LUFS is the BS.1770 measurement floor.
@property (nonatomic, assign) float absoluteSilenceFloorLUFS;

// Minimum silent-block count before we declare a silence region,
// expressed as seconds. Mirrors Overcast's
// `seekToNextSilenceWithMinimumSampleDuration:` argument.
@property (nonatomic, assign) NSTimeInterval minimumSilenceDuration;

// Music-detection bypass. When YES, the detector never reports silence.
// Overcast: `useSmartSpeedMusicDetection` + `OCAudioClassifier`.
@property (nonatomic, assign) BOOL musicDetectionBypass;

// Read-only observables (mirror Overcast's `averageLUFS` / `peakLUFS`).
@property (nonatomic, readonly) float averageLUFS;
@property (nonatomic, readonly) float peakLUFS;
@property (nonatomic, readonly) float currentBlockLUFS;
@property (nonatomic, readonly) NSTimeInterval currentSilenceDuration;
@property (nonatomic, readonly) BOOL isCurrentlySilent;

- (instancetype)initWithSampleRate:(double)sr channels:(NSUInteger)ch;
- (void)processInterleavedSamples:(const float * _Nonnull)samples
                            frames:(NSUInteger)frameCount;
- (void)processPlanarSamples:(const float * _Nullable const * _Nullable)channels
                     channels:(NSUInteger)channelCount
                        frames:(NSUInteger)frameCount;
- (SSSilenceDecision)currentDecision;
- (void)reset;

@end

NS_ASSUME_NONNULL_END

#endif /* SS_SILENCE_DETECTOR_H */
