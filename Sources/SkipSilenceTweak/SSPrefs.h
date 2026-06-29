//
//  SSPrefs.h
//  SkipSilenceYT
//

#ifndef SS_PREFS_H
#define SS_PREFS_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kSSPrefsDomain;          // com.ytlite.skipsilence
extern NSString * const kSSPrefEnabled;          // master enable
extern NSString * const kSSPrefSmartSpeedEnabled;
extern NSString * const kSSPrefSkipSilences;
extern NSString * const kSSPrefSilenceSkippingSpeed;
extern NSString * const kSSPrefUserPlaybackRate;
extern NSString * const kSSPrefLoudnessTargetLUFS;
extern NSString * const kSSPrefMinimumSilenceDuration;
extern NSString * const kSSPrefMusicDetectionBypass;
extern NSString * const kSSPrefVoiceBoostEnabled;
extern NSString * const kSSPrefVoiceBoostTargetLUFS;
extern NSString * const kSSPrefTotalSavedSeconds;
extern NSString * const kSSPrefTotalPlayedSeconds;
extern NSString * const kSSPrefsChangedNotification;

@interface SSPrefs : NSObject

@property (class, readonly, strong) SSPrefs *shared;

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL smartSpeedEnabled;
@property (nonatomic, assign) BOOL skipSilences;
@property (nonatomic, assign) float silenceSkippingSpeed;
@property (nonatomic, assign) float userPlaybackRate;
@property (nonatomic, assign) float loudnessTargetLUFS;
@property (nonatomic, assign) NSTimeInterval minimumSilenceDuration;
@property (nonatomic, assign) BOOL musicDetectionBypass;
@property (nonatomic, assign) BOOL voiceBoostEnabled;
@property (nonatomic, assign) float voiceBoostTargetLUFS;
@property (nonatomic, assign) NSTimeInterval totalSavedSeconds;
@property (nonatomic, assign) NSTimeInterval totalPlayedSeconds;

- (void)reload;
- (void)synchronize;

@end

NS_ASSUME_NONNULL_END

#endif /* SS_PREFS_H */
