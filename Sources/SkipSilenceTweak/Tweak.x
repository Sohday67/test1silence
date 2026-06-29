//
//  Tweak.x
//  SkipSilenceYT
//
//  Logos hooks that install the Skip Silence / Smart Speed controller
//  on the YouTube AVPlayer instance. Mirrors Overcast's behavior of
//  attaching an audio tap to the active streamer when the player
//  becomes ready to play.
//
//  Hooks:
//    - [YTPlayerViewController player]     -> attach our controller
//    - [AVPlayer play]                     -> arm controller if needed
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "SSPrefs.h"
#import "SSSmartSpeedController.h"
#import "SSAudioTap.h"
#import "SSLogger.h"

// Forward declaration of the YouTube private class so Logos can hook it
// without a full header. The class exists in the YouTube binary at
// runtime; this declaration only satisfies the compiler.
@interface YTPlayerViewController : UIViewController
- (AVPlayer *)player;
@end

@interface AVPlayer (SkipSilence)
@end

static char kSSControllerKey;  // objc_setAssociatedObject key

// --- Helpers -----------------------------------------------------------------

static SSSmartSpeedController *ss_getController(AVPlayer *player) {
    if (!player) return nil;
    return objc_getAssociatedObject(player, &kSSControllerKey);
}

static void ss_attachController(AVPlayer *player) {
    if (!player) return;
    SSPrefs *p = [SSPrefs shared];
    if (!p.enabled) {
        SSLog(@"Skip Silence disabled by master toggle; not attaching.");
        return;
    }

    SSSmartSpeedController *existing = ss_getController(player);
    if (existing) {
        // Re-sync config in case the user changed settings.
        existing.userRate = p.userPlaybackRate;
        existing.silenceSkippingSpeed = p.silenceSkippingSpeed;
        existing.minimumSilenceDurationToSkip = p.minimumSilenceDuration;
        existing.enabled = p.smartSpeedEnabled;
        return;
    }

    SSSmartSpeedController *c =
        [[SSSmartSpeedController alloc] initWithPlayer:player];
    c.userRate = p.userPlaybackRate;
    c.silenceSkippingSpeed = p.silenceSkippingSpeed;
    c.minimumSilenceDurationToSkip = p.minimumSilenceDuration;
    c.enabled = p.smartSpeedEnabled;
    [c start];
    objc_setAssociatedObject(player, &kSSControllerKey, c,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SSLog(@"Attached Smart Speed controller to player %@", player);
}

// --- AVPlayer hook (catch-all) ----------------------------------------------
// We hook -[AVPlayer play] to catch the moment playback is about to start.
// This is the lowest-risk entry point because YouTube wraps AVPlayer in
// several layers of private classes; hooking -play covers all of them.

%hook AVPlayer

- (void)play {
    %orig;
    ss_attachController(self);
}

- (void)setRate:(float)rate {
    // If a controller is attached and the user is asking for rate 1.0,
    // that's likely YouTube resetting on user-initiated pause/resume —
    // propagate it to the controller's userRate so Smart Speed doesn't
    // fight the user.
    SSSmartSpeedController *c = ss_getController(self);
    if (c && rate > 0.0f && fabsf(rate - 1.0f) < 0.01f) {
        c.userRate = rate;
    }
    %orig;
}

%end

// --- YTPlayerViewController hook (backup entry point) -----------------------
// If AVPlayer -play is not called for some pre-roll path, this catches the
// YT player view's main player instance.

%hook YTPlayerViewController
- (AVPlayer *)player {
    AVPlayer *orig = %orig;
    if ([orig isKindOfClass:[AVPlayer class]]) {
        ss_attachController(orig);
    }
    return orig;
}
%end

// --- Constructor: react to settings changes ---------------------------------

static void ss_prefs_changed(CFNotificationCenterRef center,
                             void *observer,
                             CFStringRef name,
                             const void *object,
                             CFDictionaryRef userInfo) {
    SSPrefs *p = [SSPrefs shared];
    [p reload];
    SSLog(@"Prefs reloaded: enabled=%d smartSpeed=%d skipSilences=%d rate=%.2f",
          (int)p.enabled, (int)p.smartSpeedEnabled, (int)p.skipSilences,
          p.silenceSkippingSpeed);
}

%ctor {
    @autoreleasepool {
        // Make sure NSUserDefaults picks up our defaults immediately.
        [[SSPrefs shared] reload];

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, ss_prefs_changed,
            (CFStringRef)@"com.ytlite.skipsilence.prefschanged",
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        SSLog(@"Loaded. Smart Speed = %d, Skip Silences = %d",
              (int)[SSPrefs shared].smartSpeedEnabled,
              (int)[SSPrefs shared].skipSilences);
    }
}
