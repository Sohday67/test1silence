//
//  SSAudioTap.m
//  SkipSilenceYT
//

#import "SSAudioTap.h"
#import "SSLogger.h"

@interface SSAudioTap ()
{
    MTAudioProcessingTapRef _tap;
    AVAudioMix *_originalMix;
    AVPlayerItem *_item;
    AudioStreamBasicDescription _currentASBD;
    BOOL _formatKnown;
}
@end

// C trampoline used as the MTAudioProcessingTap callback.
static void ss_tap_process_cb(MTAudioProcessingTapRef tap,
                              CMItemCount numberFrames,
                              MTAudioProcessingTapFlags flags,
                              AudioBufferList *bufferListInOut,
                              CMItemCount *numberFramesOut,
                              MTAudioProcessingTapFlags *flagsOut);

// Per-tap context: a weak ref back to the SSAudioTap owner.
typedef struct {
    __unsafe_unretained SSAudioTap *owner;
} SSTapContext;

static CFStringRef ss_tap_context_key = CFSTR("com.ytlite.skipsilence.tapctx");

@implementation SSAudioTap

- (instancetype)init {
    self = [super init];
    if (self) {
        _detector = [[SSSilenceDetector alloc] initWithSampleRate:48000.0 channels:2];
        _formatKnown = NO;
    }
    return self;
}

- (void)dealloc {
    [self uninstall];
}

- (BOOL)installOnPlayerItem:(AVPlayerItem *)item error:(NSError **)error {
    if (_tap) {
        if (error) {
            *error = [NSError errorWithDomain:@"SSAudioTap" code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"tap already installed"}];
        }
        return NO;
    }
    if (!item) {
        if (error) {
            *error = [NSError errorWithDomain:@"SSAudioTap" code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"nil player item"}];
        }
        return NO;
    }

    _item = item;
    _originalMix = [item.audioMix copy];

    // Create the processing tap.
    MTAudioProcessingTapCallbacks callbacks = {
        .version = kMTAudioProcessingTapCallbacksVersion_0,
        .clientInfo = (__bridge void *)self,
        .init         = NULL,
        .finalize     = NULL,
        .prepare      = NULL,  // we read the format lazily in process
        .process      = ss_tap_process_cb,
        .unprepare    = NULL,
    };

    OSStatus status = MTAudioProcessingTapCreate(kCFAllocatorDefault,
                                                 &callbacks,
                                                 kMTAudioProcessingTapCreationFlag_PreEffects,
                                                 &_tap);
    if (status != noErr || !_tap) {
        if (error) {
            *error = [NSError errorWithDomain:@"SSAudioTap" code:(int)status
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                     [NSString stringWithFormat:@"MTAudioProcessingTapCreate failed: %d", (int)status]}];
        }
        return NO;
    }

    // Build a new audio mix that uses our tap on every audio track.
    AVMutableAudioMix *newMix = [AVMutableAudioMix audioMix];
    NSMutableArray *params = [NSMutableArray array];
    NSArray *tracks = [item.tracks filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *_) {
            return [[(AVPlayerItemTrack *)obj assetTrack] hasMediaCharacteristic:AVMediaCharacteristicAudible];
        }]];

    for (AVPlayerItemTrack *track in tracks) {
        AVMutableAudioMixInputParameters *p =
            [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:track.assetTrack];
        [p setAudioTapProcessor:_tap];
        [params addObject:p];
    }
    newMix.inputParameters = params;
    item.audioMix = newMix;

    _isInstalled = YES;
    SSLog(@"SSAudioTap installed on %lu audio tracks", (unsigned long)params.count);
    return YES;
}

- (void)uninstall {
    if (_item) {
        _item.audioMix = _originalMix;
        _item = nil;
    }
    _originalMix = nil;
    if (_tap) {
        CFRelease(_tap);
        _tap = NULL;
    }
    _isInstalled = NO;
    _formatKnown = NO;
}

- (void)reconfigureWithSampleRate:(double)sr
                          channels:(NSUInteger)ch
               loudnessTargetLUFS:(float)threshold
           minimumSilenceDuration:(NSTimeInterval)duration
            musicDetectionBypass:(BOOL)bypass {
    [_detector reset];
    _detector.sampleRate = sr;
    _detector.channelCount = ch;
    _detector.loudnessTargetLUFS = threshold;
    _detector.minimumSilenceDuration = duration;
    _detector.musicDetectionBypass = bypass;
}

// Called from the audio thread by ss_tap_process_cb.
- (void)processBufferList:(AudioBufferList *)abl
                 framesIn:(CMItemCount)framesIn {
    @synchronized(self) {
        if (!_formatKnown) {
            // Walk the AudioBufferList to figure out channel count.
            UInt32 ch = 0;
            for (UInt32 i = 0; i < abl->mNumberBuffers; i++) {
                ch += abl->mBuffers[i].mNumberChannels;
            }
            if (ch == 0) ch = 2;
            double sr = 44100.0; // AVPlayer decodes everything to 44.1k/48k
            _detector.sampleRate = sr;
            _detector.channelCount = ch;
            _formatKnown = YES;
            SSLog(@"SSAudioTap: detected %u channels @ %.0f Hz", (unsigned)ch, sr);
        }
    }

    if (abl->mNumberBuffers == 1) {
        // Interleaved
        const float *data = (const float *)abl->mBuffers[0].mData;
        UInt32 ch = abl->mBuffers[0].mNumberChannels;
        [_detector processInterleavedSamples:data
                                       frames:(NSUInteger)(framesIn / MAX((UInt32)1, ch))];
    } else {
        // Planar
        const float *views[16];
        UInt32 ch = 0;
        for (UInt32 i = 0; i < abl->mNumberBuffers && i < 16; i++) {
            views[i] = (const float *)abl->mBuffers[i].mData;
            ch += abl->mBuffers[i].mNumberChannels;
        }
        [_detector processPlanarSamples:views
                                channels:ch
                                   frames:(NSUInteger)framesIn];
    }

    // Notify delegate (throttled — only on state transitions).
    if ([_delegate respondsToSelector:@selector(audioTap:didMeasureLUFS:isSilent:silenceDuration:)]) {
        [_delegate audioTap:self
              didMeasureLUFS:_detector.currentBlockLUFS
                    isSilent:_detector.isCurrentlySilent
           silenceDuration:_detector.currentSilenceDuration];
    }
}

@end

// ----- C trampoline ------------------------------------------------------------

static void ss_tap_process_cb(MTAudioProcessingTapRef tap,
                              CMItemCount numberFrames,
                              MTAudioProcessingTapFlags flags,
                              AudioBufferList *bufferListInOut,
                              CMItemCount *numberFramesOut,
                              MTAudioProcessingTapFlags *flagsOut) {
    // Recover the SSAudioTap owner from the tap's clientInfo (set in
    // MTAudioProcessingTapCreate).
    SSAudioTap *owner = (__bridge SSAudioTap *)
        MTAudioProcessingTapGetStorage(tap);
    if (owner) {
        [owner processBufferList:bufferListInOut framesIn:numberFrames];
    }
    *numberFramesOut = numberFrames;
    *flagsOut = flags;
}
