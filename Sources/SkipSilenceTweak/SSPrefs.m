//
//  SSPrefs.m
//  SkipSilenceYT
//

#import "SSPrefs.h"

NSString * const kSSPrefsDomain               = @"com.ytlite.skipsilence";
NSString * const kSSPrefEnabled               = @"enabled";
NSString * const kSSPrefSmartSpeedEnabled     = @"smartSpeedEnabled";
NSString * const kSSPrefSkipSilences          = @"skipSilences";
NSString * const kSSPrefSilenceSkippingSpeed  = @"silenceSkippingSpeed";
NSString * const kSSPrefUserPlaybackRate      = @"userPlaybackRate";
NSString * const kSSPrefLoudnessTargetLUFS    = @"loudnessTargetLUFS";
NSString * const kSSPrefMinimumSilenceDuration = @"minimumSilenceDuration";
NSString * const kSSPrefMusicDetectionBypass  = @"musicDetectionBypass";
NSString * const kSSPrefVoiceBoostEnabled     = @"voiceBoostEnabled";
NSString * const kSSPrefVoiceBoostTargetLUFS  = @"voiceBoostTargetLUFS";
NSString * const kSSPrefTotalSavedSeconds     = @"totalSavedSeconds";
NSString * const kSSPrefTotalPlayedSeconds    = @"totalPlayedSeconds";
NSString * const kSSPrefsChangedNotification  = @"SSPrefsChangedNotification";

@implementation SSPrefs

+ (SSPrefs *)shared {
    static SSPrefs *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SSPrefs alloc] init];
        [instance reload];
        // React to settings app changes via NSUserDefaultsDidChangeNotification.
        [[NSNotificationCenter defaultCenter] addObserver:instance
                                                 selector:@selector(reload)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    });
    return instance;
}

- (void)reload {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    // Defaults:
    NSDictionary *defaults = @{
        kSSPrefEnabled:               @YES,
        kSSPrefSmartSpeedEnabled:     @YES,
        kSSPrefSkipSilences:          @YES,
        kSSPrefSilenceSkippingSpeed:  @1.5f,
        kSSPrefUserPlaybackRate:      @1.0f,
        kSSPrefLoudnessTargetLUFS:    @(-10.0f),
        kSSPrefMinimumSilenceDuration:@0.20,
        kSSPrefMusicDetectionBypass:  @NO,
        kSSPrefVoiceBoostEnabled:     @NO,
        kSSPrefVoiceBoostTargetLUFS:  @(-16.0f),
        kSSPrefTotalSavedSeconds:     @0.0,
        kSSPrefTotalPlayedSeconds:    @0.0,
    };
    [d registerDefaults:defaults];
    // Trigger a re-read of all properties (they read directly from defaults).
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSSPrefsChangedNotification object:self];
}

- (void)synchronize {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Property accessors read directly from NSUserDefaults so changes made in
// the Settings.app / YTLite panel are reflected immediately.
#define SS_PROP_GET(type, name, key, default) \
    - (type)name { \
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; \
        id v = [d objectForKey:key]; \
        return v ? [v floatValue] : default; \
    }
#define SS_PROP_GET_BOOL(name, key) \
    - (BOOL)name { \
        return [[NSUserDefaults standardUserDefaults] boolForKey:key]; \
    }
#define SS_PROP_GET_DOUBLE(name, key, default) \
    - (NSTimeInterval)name { \
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; \
        id v = [d objectForKey:key]; \
        return v ? [v doubleValue] : default; \
    }
#define SS_PROP_SET(type, name, key) \
    - (void)setName:(type)v { \
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; \
        [d setFloat:v forKey:key]; \
        [self postChange]; \
    }
#define SS_PROP_SET_BOOL(name, key) \
    - (void)setName:(BOOL)v { \
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; \
        [d setBool:v forKey:key]; \
        [self postChange]; \
    }
#define SS_PROP_SET_DOUBLE(name, key) \
    - (void)setName:(NSTimeInterval)v { \
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults]; \
        [d setDouble:v forKey:key]; \
        [self postChange]; \
    }

SS_PROP_GET_BOOL(enabled, kSSPrefEnabled)
SS_PROP_SET_BOOL(enabled, kSSPrefEnabled)

SS_PROP_GET_BOOL(smartSpeedEnabled, kSSPrefSmartSpeedEnabled)
SS_PROP_SET_BOOL(smartSpeedEnabled, kSSPrefSmartSpeedEnabled)

SS_PROP_GET_BOOL(skipSilences, kSSPrefSkipSilences)
SS_PROP_SET_BOOL(skipSilences, kSSPrefSkipSilences)

SS_PROP_GET(float, silenceSkippingSpeed, kSSPrefSilenceSkippingSpeed, 1.5f)
SS_PROP_SET(float, silenceSkippingSpeed, kSSPrefSilenceSkippingSpeed)

SS_PROP_GET(float, userPlaybackRate, kSSPrefUserPlaybackRate, 1.0f)
SS_PROP_SET(float, userPlaybackRate, kSSPrefUserPlaybackRate)

SS_PROP_GET(float, loudnessTargetLUFS, kSSPrefLoudnessTargetLUFS, -10.0f)
SS_PROP_SET(float, loudnessTargetLUFS, kSSPrefLoudnessTargetLUFS)

SS_PROP_GET_DOUBLE(minimumSilenceDuration, kSSPrefMinimumSilenceDuration, 0.20)
SS_PROP_SET_DOUBLE(minimumSilenceDuration, kSSPrefMinimumSilenceDuration)

SS_PROP_GET_BOOL(musicDetectionBypass, kSSPrefMusicDetectionBypass)
SS_PROP_SET_BOOL(musicDetectionBypass, kSSPrefMusicDetectionBypass)

SS_PROP_GET_BOOL(voiceBoostEnabled, kSSPrefVoiceBoostEnabled)
SS_PROP_SET_BOOL(voiceBoostEnabled, kSSPrefVoiceBoostEnabled)

SS_PROP_GET(float, voiceBoostTargetLUFS, kSSPrefVoiceBoostTargetLUFS, -16.0f)
SS_PROP_SET(float, voiceBoostTargetLUFS, kSSPrefVoiceBoostTargetLUFS)

SS_PROP_GET_DOUBLE(totalSavedSeconds, kSSPrefTotalSavedSeconds, 0.0)
SS_PROP_SET_DOUBLE(totalSavedSeconds, kSSPrefTotalSavedSeconds)

SS_PROP_GET_DOUBLE(totalPlayedSeconds, kSSPrefTotalPlayedSeconds, 0.0)
SS_PROP_SET_DOUBLE(totalPlayedSeconds, kSSPrefTotalPlayedSeconds)

- (void)postChange {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSSPrefsChangedNotification object:self];
}

@end
