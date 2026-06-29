//
//  SSSilenceDetector.m
//  SkipSilenceYT
//

#import "SSSilenceDetector.h"

@interface SSSilenceDetector ()
{
    SSLUFSState _lufs;
    double _emaAverageLUFS;        // exponential moving average, LUFS
    double _emaPeakLUFS;           // EMA of short-term peak
    double _blockLUFS;
    NSTimeInterval _silenceAccumulator;
    BOOL _isCurrentlySilent;
    NSUInteger _blocksProcessed;
}
@end

@implementation SSSilenceDetector

- (instancetype)initWithSampleRate:(double)sr channels:(NSUInteger)ch {
    self = [super init];
    if (self) {
        _sampleRate = sr;
        _channelCount = ch;
        _loudnessTargetLUFS = -10.0f;     // 10 LU below running average = silence
        _absoluteSilenceFloorLUFS = -70.0f;
        _minimumSilenceDuration = 0.20;   // Overcast's "Shorter silences" hint
        _musicDetectionBypass = NO;

        _emaAverageLUFS = -70.0;
        _emaPeakLUFS = -70.0;
        _blockLUFS = -70.0;
        _silenceAccumulator = 0.0;
        _isCurrentlySilent = NO;
        _blocksProcessed = 0;

        sslufs_init(&_lufs, sr, (unsigned)MIN(ch, (NSUInteger)8));
    }
    return self;
}

- (void)processInterleavedSamples:(const float *)samples
                            frames:(NSUInteger)frameCount {
    if (_musicDetectionBypass) return;
    if (samples == NULL || frameCount == 0) return;

    sslufs_process_interleaved(&_lufs, samples,
                               (unsigned)MIN(_channelCount, (NSUInteger)8),
                               (unsigned)frameCount);

    [self updateStateFromLUFS];
}

- (void)processPlanarSamples:(const float *const *)channels
                     channels:(NSUInteger)channelCount
                        frames:(NSUInteger)frameCount {
    if (_musicDetectionBypass) return;
    if (channels == NULL || frameCount == 0) return;

    sslufs_process_chunk(&_lufs, channels,
                         (unsigned)MIN(channelCount, (NSUInteger)8),
                         (unsigned)frameCount);

    [self updateStateFromLUFS];
}

- (void)updateStateFromLUFS {
    // sslufs_finalize_block is called automatically inside process_*
    // when a 400 ms block fills up; we just read the latest value.
    double lufs = sslufs_current_lufs(&_lufs);
    if (lufs <= -120.0) return;

    _blockLUFS = (float)lufs;
    _blocksProcessed += 1;

    /* Pass 1: running average (program loudness).
     * Use a slow EMA (α = 0.01) so a single silent block doesn't drag
     * the average down — exactly the role of Overcast's pass-1
     * premeasurement. */
    double alphaAvg = 0.01;
    _emaAverageLUFS = (1.0 - alphaAvg) * _emaAverageLUFS + alphaAvg * lufs;

    /* Pass 2: short-term peak (silence reference).
     * Fast attack (α = 0.5), slow release (α = 0.005) — emulates
     * Overcast's "Pass 2 using peak %g LUFS" pass. */
    if (lufs > _emaPeakLUFS) {
        double alphaAttack = 0.5;
        _emaPeakLUFS = (1.0 - alphaAttack) * _emaPeakLUFS + alphaAttack * lufs;
    } else {
        double alphaRelease = 0.005;
        _emaPeakLUFS = (1.0 - alphaRelease) * _emaPeakLUFS + alphaRelease * lufs;
    }

    /* Decision: silence if the block LUFS is more than `loudnessTargetLUFS`
     * below the running average (relative threshold), OR if it's below
     * the absolute silence floor. */
    BOOL silent = (lufs < (_emaAverageLUFS + _loudnessTargetLUFS)) ||
                  (lufs < _absoluteSilenceFloorLUFS);

    double blockDuration = 0.400; // 400 ms gating block
    if (silent) {
        _silenceAccumulator += blockDuration;
        if (_silenceAccumulator >= _minimumSilenceDuration) {
            _isCurrentlySilent = YES;
        }
    } else {
        _silenceAccumulator = 0.0;
        _isCurrentlySilent = NO;
    }
}

- (SSSilenceDecision)currentDecision {
    if (_musicDetectionBypass) return SSSilenceDecisionSpeech;
    if (_blocksProcessed < 3) return SSSilenceDecisionUndetermined;
    return _isCurrentlySilent ? SSSilenceDecisionSilence : SSSilenceDecisionSpeech;
}

- (void)reset {
    sslufs_init(&_lufs, _sampleRate, (unsigned)MIN(_channelCount, (NSUInteger)8));
    _emaAverageLUFS = -70.0;
    _emaPeakLUFS = -70.0;
    _blockLUFS = -70.0;
    _silenceAccumulator = 0.0;
    _isCurrentlySilent = NO;
    _blocksProcessed = 0;
}

- (float)averageLUFS { return (float)_emaAverageLUFS; }
- (float)peakLUFS    { return (float)_emaPeakLUFS;    }
- (float)currentBlockLUFS { return (float)_blockLUFS; }
- (NSTimeInterval)currentSilenceDuration { return _silenceAccumulator; }
- (BOOL)isCurrentlySilent { return _isCurrentlySilent; }

@end
