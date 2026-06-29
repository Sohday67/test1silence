//
//  SSSmartSpeedController.m
//  SkipSilenceYT
//

#import "SSSmartSpeedController.h"
#import "SSPrefs.h"
#import "SSLogger.h"

@interface SSSmartSpeedController ()
{
    BOOL _wasSilent;
    NSTimeInterval _silenceStartedAt;
    NSTimeInterval _silenceAccumulator;
    NSTimeInterval _playStartedAt;
    NSTimeInterval _lastSampleTime;
}
@end

@implementation SSSmartSpeedController

- (instancetype)initWithPlayer:(AVPlayer *)player {
    self = [super init];
    if (self) {
        _player = player;
        _tap = [[SSAudioTap alloc] init];
        _tap.delegate = self;
        _userRate = 1.0f;
        _silenceSkippingSpeed = 1.5f;
        _minimumSilenceDurationToSkip = 0.20;
        _enabled = YES;
        _wasSilent = NO;
        _silenceStartedAt = 0;
        _silenceAccumulator = 0;
        _playStartedAt = 0;
        _lastSampleTime = 0;

        // Hydrate settings from NSUserDefaults.
        SSPrefs *p = [SSPrefs shared];
        _enabled = p.smartSpeedEnabled;
        _silenceSkippingSpeed = p.silenceSkippingSpeed;
        _userRate = p.userPlaybackRate;
    }
    return self;
}

- (void)start {
    if (!_player) return;

    [_player addObserver:self
              forKeyPath:@"currentItem"
                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                 context:NULL];

    [self installTapOnCurrentItem];
    _playStartedAt = CFAbsoluteTimeGetCurrent();
}

- (void)stop {
    @try {
        [_player removeObserver:self forKeyPath:@"currentItem"];
    } @catch (id _) {}
    [self uninstallTap];
}

- (void)dealloc {
    [self stop];
}

- (void)installTapOnCurrentItem {
    AVPlayerItem *item = _player.currentItem;
    if (!item) return;
    NSError *err = nil;
    if (![_tap installOnPlayerItem:item error:&err]) {
        SSLog(@"SSSmartSpeedController: tap install failed: %@", err);
    }
}

- (void)uninstallTap {
    [_tap uninstall];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem"]) {
        [self uninstallTap];
        [self installTapOnCurrentItem];
    }
}

// SSAudioTapDelegate
- (void)audioTap:(SSAudioTap *)tap
   didMeasureLUFS:(float)lufs
        isSilent:(BOOL)isSilent
  silenceDuration:(NSTimeInterval)duration {
    if (!_enabled) return;
    if (!_player) return;

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (_lastSampleTime == 0) _lastSampleTime = now;
    NSTimeInterval dt = now - _lastSampleTime;
    _lastSampleTime = now;

    // Track total played time.
    SSPrefs *p = [SSPrefs shared];
    p.totalPlayedSeconds += dt;

    if (isSilent) {
        if (!_wasSilent) {
            _wasSilent = YES;
            _silenceStartedAt = now;
        }
        if (duration >= _minimumSilenceDurationToSkip) {
            // Bump rate during silence. The sample-accurate variant
            // -[AVPlayer setRate:time:atHostTime:] is private; we use the
            // public `rate` property setter, which is good enough for
            // ~50 ms granularity.
            if (_player.rate != _silenceSkippingSpeed) {
                _player.rate = _silenceSkippingSpeed;
            }
        }
    } else {
        if (_wasSilent) {
            // Speech resumed — accumulate savings and restore user rate.
            NSTimeInterval skipped = (now - _silenceStartedAt) *
                                     (_silenceSkippingSpeed - _userRate);
            if (skipped > 0) {
                _silenceAccumulator += skipped;
                p.totalSavedSeconds += skipped;
            }
            _wasSilent = NO;
            _silenceStartedAt = 0;
        }
        // Restore user's preferred rate.
        if (_player.rate != _userRate) {
            _player.rate = _userRate;
        }
    }
}

- (NSTimeInterval)totalSavedSeconds {
    return [SSPrefs shared].totalSavedSeconds;
}

- (NSTimeInterval)totalPlayedSeconds {
    return [SSPrefs shared].totalPlayedSeconds;
}

- (void)resetStats {
    SSPrefs *p = [SSPrefs shared];
    p.totalSavedSeconds = 0;
    p.totalPlayedSeconds = 0;
    _silenceAccumulator = 0;
}

- (NSDictionary<NSString *, NSNumber *> *)statsDictionary {
    SSPrefs *p = [SSPrefs shared];
    double saved = p.totalSavedSeconds;
    double played = p.totalPlayedSeconds;
    double pct = played > 0 ? (saved / played) * 100.0 : 0.0;
    return @{
        @"saved": @(saved),
        @"played": @(played),
        @"percent": @(pct),
    };
}

@end
