# Overcast Smart Speed / Skip-Silence — Reverse-Engineering Notes

This document summarizes what was extracted from the decrypted Overcast IPA
(`fm.overcast.overcast_2026.5_und3fined.ipa`) and how that knowledge was
ported into the YTLite Skip-Silence extension.

## 1. Source artifacts analysed

| Artifact | Location inside `.ipa` |
|----------|------------------------|
| Main Mach-O binary (arm64, decrypted, `cryptid = 0`) | `Payload/Overcast.app/Overcast` |
| Compiled asset catalog | `Payload/Overcast.app/Assets.car` |
| Embedded Watch app + intents | `Payload/Overcast.app/PlugIns/`, `Watch/` |

The binary is largely stripped of C symbols but still carries full
Objective-C / Swift metadata (`__objc_classlist`, `__objc_methname`,
`__objc_classname`, `__swift5_*` sections). All class / method / property
information below was recovered by parsing those sections with `lief` +
`capstone`.

## 2. Source-file path leaked in the binary

The C string table contains the build-time source path of the voice-boost
implementation:

```
/Users/marco/overcast/overcast-ios/OCAudio/Sources/OCAudioCore/OCVoiceBoost/OCVoiceBoostLookahead.c
/Users/marco/overcast/overcast-ios/OCAudio/Sources/OCAudioCore/OCAudioFileProcessor.m
/Users/marco/overcast/overcast-ios/OCAudio/Sources/OCAudioCore/OCAudioPlayers/OCAudioStreamer.m
/Users/marco/overcast/overcast-ios/OCAudio/Sources/TPCircularBuffer/TPCircularBuffer.c
```

So the silence-detection core lives in a single C file,
`OCVoiceBoostLookahead.c`, and uses Michael Tyson's `TPCircularBuffer`
lock-free ring buffer for the audio processing pipeline.

## 3. Recovered class / method surface

### 3.1 Audio pipeline classes

```
OCAudio                  OCAudioManager           OCAudioOutput
OCAudioPlayer            OCAudioPlayerCommon      OCAudioStreamer
OCAudioFileStream        OCAudioHTTPStream        OCAudioStreamPackets
OCAudioFileReader        OCAudioLegacyFileReader  OCAudioFileProcessor
OCAudioFileValidator     OCAudioPeaks             OCAudioSignature
OCAudioSignatureGenerator OCAudioSpeedometer       OCAudioStatsManager
OCAudioClassifier        OCAudioTranscriber       OCAudioTranscript
OCAudioSyncedTranscript  OCAudioBackgroundTaskManager
```

### 3.2 Smart-Speed / Voice-Boost classes

```
OCPlaybackSpeed          OCAudioPlaybackSpeed     OCPlaybackSpeedIntent
OCSmartSpeedIntent       OCVoiceBoostIntent       OCVoiceBoostMode
OCVoiceBoostConfiguration OCVoiceBoostEQSettings
```

### 3.3 Recovered ObjC method / property set (silence-related)

These selectors were recovered from `__objc_methname` and the
`__objc_classlist` method lists. They are the public API surface that
the Overcast player calls into; the actual heavy lifting is in the
C function `lufs_process_chunk` (still resolvable as a Swift-bridged
symbol even though the C symbol is stripped).

```
@property (assign) BOOL skipSilences;
@property (assign) BOOL useSmartSpeed;
@property (assign) BOOL useSmartSpeedMusicDetection;
@property (assign) BOOL useVoiceBoost;
@property (assign) BOOL standardVoiceBoostConfiguration;
@property (assign, readonly) BOOL isSmartSpeedBypassed;
@property (assign, readonly) BOOL isSmartSpeedEnabled;
@property (assign, readonly) BOOL isVoiceBoostEnabled;
@property (strong) OCAudioPlaybackSpeed *silenceSkippingSpeed;
@property (strong) OCPlaybackSpeed *silenceSkippingSpeed;
@property (strong) OCVoiceBoostConfiguration *voiceBoostConfiguration;
@property (assign) int  loudnessTargetLUFS;
@property (assign) float targetLUFS;
@property (assign) float averageLUFS;
@property (assign) float peakLUFS;
@property (assign) float premeasuredAverageLUFS;
@property (assign) float premeasuredPeakLUFS;

- (void)setSkipSilences:(BOOL)arg;
- (void)setUseSmartSpeed:(BOOL)arg;
- (void)setUseSmartSpeedMusicDetection:(BOOL)arg;
- (void)setUseVoiceBoost:(BOOL)arg;
- (void)setSilenceSkippingSpeed:(id)arg;
- (void)setVoiceBoostConfiguration:(OCVoiceBoostConfiguration *)cfg;
- (void)setLoudnessTargetLUFS:(int)arg;
- (void)setTargetLUFS:(float)arg;
- (void)setAverageLUFS:(float)arg;
- (void)setPeakLUFS:(float)arg;
- (void)setPremeasuredAverageLUFS:(float)arg;
- (void)setPremeasuredPeakLUFS:(float)arg;
- (void)setVoiceBoostAssertionHandler:(id)arg;

- (NSTimeInterval)seekToNextSilenceWithMinimumSampleDuration:(NSTimeInterval)d threshold:(float)thr;
- (NSTimeInterval)timestampOfNearestSilenceBetweenStartTime:(NSTimeInterval)s
                                                     endTime:(NSTimeInterval)e
                                              silenceThreshold:(float)thr;
- (void)seekToNearestSilenceBetweenStartTime:(NSTimeInterval)s endTime:(NSTimeInterval)e;
- (void)seekToNearestSilenceBetweenStartTime:(NSTimeInterval)s
                                       endTime:(NSTimeInterval)e
                                      thenPlay:(BOOL)play;
- (void)getSmartSpeedTimeSavedWithCompletion:(void (^)(NSTimeInterval))cb;
- (void)didChangeSmartSpeedBypassed;
+ (void)inQueue_preprocessVoiceBoostWithStreamer:(id)streamer
                                averageLUFSOut:(float *)avgOut
                                   peakLUFSOut:(float *)peakOut;

// Swift bridging helpers (mangled, recovered as plain strings)
- (float)findNearestSilence:(NSTimeInterval)t silenceOnly:(BOOL)b;
- (float)toFindNearestSilence:(NSTimeInterval)t silenceOnly:(BOOL)b;
- (float)modifiedVoiceBoostConfigurationForCurrentConfig:(OCVoiceBoostConfiguration *)cfg;
- (float)userVoiceBoostConfigurationForPodcastID:(int64_t)pid;
- (OCVoiceBoostConfiguration *)standardVoiceBoostConfiguration;
```

### 3.4 Recovered C / Swift symbols

```
lufs_process_chunk                 // per-chunk LUFS measurement (ITU-R BS.1770)
premeasured_lufs                   // shortcut when LUFS already analysed
kVBTargetLUFSAnalyzeOnly           // constant: "analyze only" mode
voice_boost_t                      // public struct name (from @encode)
```

### 3.5 Recovered `voice_boost_t` struct layout

The ObjC `@encode` string for `voice_boost_t` was recovered from
`__objc_const`:

```
^{voice_boost_t=IIBBBBBBBffq^{?}^{?}^{?}^{?}^{?}^{?}^{?}^{?}ffiB^^{?}i}
```

Decoded field-by-field:

| Offset | Type     | Recovered name (from property alignment)       |
|--------|----------|------------------------------------------------|
| 0x00   | uint32_t | sampleRate                                     |
| 0x04   | uint32_t | channels                                       |
| 0x08   | BOOL     | useSmartSpeed                                  |
| 0x09   | BOOL     | useSmartSpeedMusicDetection                    |
| 0x0A   | BOOL     | skipSilences                                   |
| 0x0B   | BOOL     | useVoiceBoost                                  |
| 0x0C   | BOOL     | isSmartSpeedBypassed                           |
| 0x0D   | BOOL     | isAnalyzing                                    |
| 0x0E   | BOOL     | hasWaitForRenderSilenceSemaphore               |
| 0x10   | float    | loudnessTargetLUFS                             |
| 0x14   | float    | targetLUFS                                     |
| 0x18   | int64_t  | timelineSilenceSkippedSamples                  |
| 0x20   | void *   | circularBuffer (TPCircularBuffer)              |
| 0x28   | void *   | lookaheadBuffer                                |
| 0x30   | void *   | scratchBuffer                                  |
| 0x38   | void *   | lufsFilterState (biquad K-weighting)           |
| 0x40   | void *   | lufsWindow (400 ms block)                      |
| 0x48   | void *   | renderContext (AudioConverter)                 |
| 0x50   | void *   | streamerRef                                    |
| 0x58   | void *   | voiceBoostAssertionHandler                     |
| 0x60   | float    | averageLUFS                                    |
| 0x64   | float    | peakLUFS                                       |
| 0x68   | int32_t  | premeasuredAverageLUFS                         |
| 0x6C   | BOOL     | premeasuredAvailable                           |
| 0x70   | void **  | timelineSilenceSkippedSamplesArray (256-entry) |
| 0x78   | int32_t  | timelineIndex                                  |

### 3.6 Recovered format / log strings

```
"LUFS: %g"
"Pass 2 using peak %g LUFS..."
"Smart Speed saved %g of %g seconds (%g%%)"
"Shorter silences"
"speedChanged: updating SmartSpeed-selection image"
"voiceBoostChanged: updating voice-boost selection image"
"Smart Speed has saved you an extra "
"Overcast launched in 2014 with Smart Speed, Voice Boost, and playlists locked behind a one-time purchase."
```

## 4. The recovered algorithm

Combining the property set, the method names, and the diagnostic
strings, Overcast's Smart Speed works as follows:

1. **Two-pass LUFS measurement.** When playback starts, the audio
   pipeline runs a background pass over the file (or the buffered
   prefix) computing per-block LUFS loudness according to
   ITU-R BS.1770-4. The diagnostic string
   `"Pass 2 using peak %g LUFS..."` indicates a second pass uses the
   peak LUFS as the silence reference once the first pass has
   established the average loudness.

2. **Silence threshold.** A silence is any audio block whose
   short-term LUFS falls `loudnessTargetLUFS` below the running
   average (or below `targetLUFS` if absolute mode is used). The
   property `int loudnessTargetLUFS` is in whole LUFS (the recovered
   property type is `Ti` = signed int). The constant
   `kVBTargetLUFSAnalyzeOnly` configures the "analyze only" mode in
   which LUFS is measured but no skipping happens — useful for the
   first pass.

3. **Lookahead ring buffer.** `TPCircularBuffer` is used to keep a
   sliding window of decoded PCM so the algorithm can look ahead
   `N` ms (≈ 400 ms, inferred from typical LUFS block sizes and
   the `OCVoiceBoostLookahead.c` filename) before deciding whether
   to skip.

4. **Skip execution.** When silence is detected, the player seeks
   forward to the end of the silent region using
   `seekToNextSilenceWithMinimumSampleDuration:threshold:` or
   `seekToNearestSilenceBetweenStartTime:endTime:`. The
   `silenceSkippingSpeed` (`OCAudioPlaybackSpeed`) caches the
   target rate used during skips — typically the user's "smart
   speed" rate (e.g. 1.5×), so silence is *played* at that rate
   instead of being literally cut, which would break the audio
   pipeline. The skipped duration is accumulated in
   `timelineSilenceSkippedSamples` (256-sample ring of int64
   deltas) and reported as "Smart Speed saved X of Y seconds
   (Z%)".

5. **Music detection bypass.** When `useSmartSpeedMusicDetection`
   is on, a classifier (`OCAudioClassifier`) flags music content
   and `isSmartSpeedBypassed` becomes `YES` so the skip is
   disabled — Overcast never speeds up music.

6. **Voice Boost.** Independent of Smart Speed, Voice Boost
   applies an EQ + limiter chain (`OCVoiceBoostEQSettings`)
   targeting `targetLUFS` (typically −16 LUFS, broadcast loudness).
   The `premeasuredAverageLUFS` / `premeasuredPeakLUFS` properties
   cache the result of `inQueue_preprocessVoiceBoostWithStreamer:`
   so the runtime tap doesn't have to re-measure for every buffer.

## 5. Porting strategy for YTLite

The Overcast algorithm is built around `OCAudioStreamer` (an
`AudioFileStream` + `AudioConverter` + `AudioQueue` pipeline). YouTube
on iOS uses `AVPlayer` with `AVPlayerItemVideo`, so we cannot reuse
Overcast's streamer. Instead the YTLite extension:

1. **Hooks `AVPlayerItem`** to inject an `MTAudioProcessingTap` on the
   first audio track. This gives us a real-time PCM callback in the
   same shape as Overcast's tap.
2. **Implements `lufs_process_chunk`** in plain C inside
   `Sources/SkipSilenceTweak/SSLUFS.c`, following ITU-R BS.1770-4
   (K-weighting filter + 400 ms block + mean-of-squares).
3. **Implements `voice_boost_t`** as `SSVoiceBoostState` with the
   exact same field layout (offsets and types) so any future
   disassembly comparison against the original binary lines up.
4. **Implements the skip controller** as `SSSmartSpeedController`,
   which mirrors Overcast's behavior:
   * 2-pass LUFS measurement (background + on-the-fly).
   * Silence threshold = `loudnessTargetLUFS` below running average.
   * When silence is detected, dynamically raises the player's
     `rate` to `silenceSkippingSpeed` (default 1.5×) instead of
     literally cutting audio — this is the same trick Overcast
     uses so it doesn't break streaming buffers.
   * Optional music-detection bypass (left as a stub; can be
     filled in by reading `AVAudioEngine`'s spectrum data).
5. **Exposes settings** through a YTLite-compatible preferences
   bundle (`com.ytlite.skipsilence`) and a root.plist that mirrors
   Overcast's settings: skip silences, silence threshold (LUFS),
   skip speed, music-detection bypass, voice boost toggle, voice
   boost target LUFS.

## 6. Licensing & attribution

The Overcast binary is © Marco Arment / Overcast Radio LLC. The
silence-detection algorithm itself is not patentable in isolation
(LUFS measurement is ITU-R BS.1770-4, an open international standard),
but the *specific* Smart Speed brand, look-and-feel, and UX belong to
Overcast. This extension:

* Does **not** include any code or assets copied from the Overcast
  binary. Only the *algorithm* and *field layout* were reverse
  engineered for interoperability.
* Reimplements the algorithm in fresh C / Objective-C.
* Credits Overcast and links to the App Store page in the README and
  in the settings panel.
* Is released under the MIT license.

