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

// Helper: register defaults once at class +load.
static void ss_register_defaults(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *defaults = @{
            kSSPrefEnabled:                @YES,
            kSSPrefSmartSpeedEnabled:      @YES,
            kSSPrefSkipSilences:           @YES,
            kSSPrefSilenceSkippingSpeed:   @1.5f,
            kSSPrefUserPlaybackRate:       @1.0f,
            kSSPrefLoudnessTargetLUFS:     @(-10.0f),
            kSSPrefMinimumSilenceDuration: @0.20,
            kSSPrefMusicDetectionBypass:   @NO,
            kSSPrefVoiceBoostEnabled:      @NO,
            kSSPrefVoiceBoostTargetLUFS:   @(-16.0f),
            kSSPrefTotalSavedSeconds:      @0.0,
            kSSPrefTotalPlayedSeconds:     @0.0,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    });
}

@implementation SSPrefs

+ (SSPrefs *)shared {
    static SSPrefs *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ss_register_defaults();
        instance = [[SSPrefs alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:instance
                                                 selector:@selector(reload)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    });
    return instance;
}

- (void)reload {
    ss_register_defaults();
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSSPrefsChangedNotification object:self];
}

- (void)synchronize {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)postChange {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSSPrefsChangedNotification object:self];
}

// --- BOOL accessors ---------------------------------------------------------

- (BOOL)enabled { return [[NSUserDefaults standardUserDefaults] boolForKey:kSSPrefEnabled]; }
- (void)setEnabled:(BOOL)v {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kSSPrefEnabled];
    [self postChange];
}

- (BOOL)smartSpeedEnabled { return [[NSUserDefaults standardUserDefaults] boolForKey:kSSPrefSmartSpeedEnabled]; }
- (void)setSmartSpeedEnabled:(BOOL)v {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kSSPrefSmartSpeedEnabled];
    [self postChange];
}

- (BOOL)skipSilences { return [[NSUserDefaults standardUserDefaults] boolForKey:kSSPrefSkipSilences]; }
- (void)setSkipSilences:(BOOL)v {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kSSPrefSkipSilences];
    [self postChange];
}

- (BOOL)musicDetectionBypass { return [[NSUserDefaults standardUserDefaults] boolForKey:kSSPrefMusicDetectionBypass]; }
- (void)setMusicDetectionBypass:(BOOL)v {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kSSPrefMusicDetectionBypass];
    [self postChange];
}

- (BOOL)voiceBoostEnabled { return [[NSUserDefaults standardUserDefaults] boolForKey:kSSPrefVoiceBoostEnabled]; }
- (void)setVoiceBoostEnabled:(BOOL)v {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kSSPrefVoiceBoostEnabled];
    [self postChange];
}

// --- Float accessors --------------------------------------------------------

- (float)silenceSkippingSpeed {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kSSPrefSilenceSkippingSpeed];
}
- (void)setSilenceSkippingSpeed:(float)v {
    [[NSUserDefaults standardUserDefaults] setFloat:v forKey:kSSPrefSilenceSkippingSpeed];
    [self postChange];
}

- (float)userPlaybackRate {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kSSPrefUserPlaybackRate];
}
- (void)setUserPlaybackRate:(float)v {
    [[NSUserDefaults standardUserDefaults] setFloat:v forKey:kSSPrefUserPlaybackRate];
    [self postChange];
}

- (float)loudnessTargetLUFS {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kSSPrefLoudnessTargetLUFS];
}
- (void)setLoudnessTargetLUFS:(float)v {
    [[NSUserDefaults standardUserDefaults] setFloat:v forKey:kSSPrefLoudnessTargetLUFS];
    [self postChange];
}

- (float)voiceBoostTargetLUFS {
    return [[NSUserDefaults standardUserDefaults] floatForKey:kSSPrefVoiceBoostTargetLUFS];
}
- (void)setVoiceBoostTargetLUFS:(float)v {
    [[NSUserDefaults standardUserDefaults] setFloat:v forKey:kSSPrefVoiceBoostTargetLUFS];
    [self postChange];
}

// --- NSTimeInterval accessors ----------------------------------------------

- (NSTimeInterval)minimumSilenceDuration {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:kSSPrefMinimumSilenceDuration];
}
- (void)setMinimumSilenceDuration:(NSTimeInterval)v {
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:kSSPrefMinimumSilenceDuration];
    [self postChange];
}

- (NSTimeInterval)totalSavedSeconds {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:kSSPrefTotalSavedSeconds];
}
- (void)setTotalSavedSeconds:(NSTimeInterval)v {
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:kSSPrefTotalSavedSeconds];
}

- (NSTimeInterval)totalPlayedSeconds {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:kSSPrefTotalPlayedSeconds];
}
- (void)setTotalPlayedSeconds:(NSTimeInterval)v {
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:kSSPrefTotalPlayedSeconds];
}

@end
