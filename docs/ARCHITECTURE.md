# Architecture overview

This document gives a more detailed picture of how the pieces fit
together at runtime. For the reverse-engineering background, see
[`OvercastAnalysis.md`](../OvercastAnalysis.md). For the high-level
overview, see the [`README.md`](../README.md).

## Runtime call graph

```
YouTube.app
   │
   ▼
AVPlayer -play                            ← %hook in Tweak.x
   │
   ├──► ss_attachController(player)
   │       │
   │       └──► SSSmartSpeedController.initWithPlayer:
   │              │   ├── reads defaults from SSPrefs (NSUserDefaults)
   │              │   ├── creates SSAudioTap
   │              │   └── calls [controller start]
   │              │
   │              ▼
   │        KVO on AVPlayer.currentItem
   │              │
   │              ▼ (whenever currentItem changes)
   │        SSAudioTap.installOnPlayerItem:
   │              │
   │              ├── creates MTAudioProcessingTap (pre-effects flag)
   │              ├── builds new AVMutableAudioMix
   │              └── assigns to AVPlayerItem.audioMix
   │
   ▼ (YouTube plays the video)
MTAudioProcessingTap process callback
   │
   ▼
SSAudioTap.processBufferList:framesIn:        ← audio thread
   │
   ├──► SSSilenceDetector.processInterleavedSamples:
   │       │
   │       ├──► sslufs_process_interleaved (SSLUFS.c)
   │       │       │
   │       │       ├── K-weighting filter (stage 1: high-shelf, stage 2: RLB)
   │       │       ├── mean-square accumulator (per channel, weighted)
   │       │       └── on 400 ms block boundary:
   │       │              finalize_block → LUFS = -0.691 + 10*log10(ms)
   │       │
   │       └── updateStateFromLUFS:
   │              ├── EMA average LUFS  (α = 0.01, slow)
   │              ├── EMA peak LUFS     (attack 0.5, release 0.005)
   │              ├── silent ← blockLUFS < (avgLUFS + loudnessTargetLUFS)
   │              └── silenceAccumulator += 0.400 if silent
   │
   └──► SSAudioTapDelegate callback:
          SSSmartSpeedController.audioTap:didMeasureLUFS:isSilent:silenceDuration:
              │
              ├── if silent && duration >= minimum:
              │       AVPlayer.rate = silenceSkippingSpeed   (1.5× by default)
              │
              └── if speech resumed:
                      accumulate savings = silenceDuration × (skipRate − userRate)
                      AVPlayer.rate = userRate                (restore)
                      SSPrefs.totalSavedSeconds += savings
                      SSPrefs.totalPlayedSeconds += dt
```

## Threading model

- **Main thread / UIKit**: settings UI, AVPlayer KVO registration.
- **AVPlayer's audio output thread**: `MTAudioProcessingTap` process
  callback. This is where `SSLUFS` runs. It's a real-time thread —
  we must not allocate, lock, or call UIKit here.
- **Background queue**: none currently. A future Voice Boost
  implementation may dispatch LUFS pre-measurement to a background
  queue (mirroring Overcast's
  `+[OCAudioPlayerCommon inQueue_preprocessVoiceBoostWithStreamer:]`).

## Synchronization points

1. `SSAudioTap.processBufferList:` reads/writes the LUFS detector from
   the audio thread. The `@synchronized(self)` block is only used to
   publish the initial `sampleRate` / `channelCount` once. After
   that, the detector runs lock-free because it's only touched from
   the audio thread.

2. `SSSmartSpeedController.audioTap:didMeasureLUFS:...` is invoked
   synchronously from the audio thread. It does `AVPlayer.rate` /
   `setRate:withTime:` which are documented as main-thread-safe by
   Apple — internally they dispatch to the player's queue.

3. `SSPrefs` property reads from the audio thread (e.g. when the
   controller appends to `totalSavedSeconds`) use atomic property
   accessors backed by `NSUserDefaults`, which is itself thread-safe.
   There's a small risk of torn reads on `double` keys but the
   accumulated drift over a session is negligible (sub-millisecond).

## Why we don't physically cut audio

Overcast's `OCAudioStreamer` uses `AudioQueueOutput` with a render
callback. Smart Speed works by *not* enqueuing silent buffers, so
the audio hardware genuinely never plays them. The skipped duration
is accumulated in `timelineSilenceSkippedSamples`.

For YouTube, we don't control the audio buffer queue — YouTube's
`AVPlayer` does. The cleanest equivalent is to dynamically bump the
player's `rate` property during silent regions. This:

- Doesn't cut audio, so the streaming pipeline stays happy.
- Maintains A/V sync (YouTube's `AVPlayer` handles rate changes
  sample-accurately via `setRate:withTime:atHostTime:`).
- Produces the same audible result (the silent section plays through
  much faster).
- Lets us compute "savings" with the same formula:
  `savings = silenceDuration × (skipRate - userRate)`.

The trade-off is that we consume a tiny amount of CPU during silence
(decoding still happens) whereas Overcast genuinely skips the decode.
For YouTube on a modern iPhone this is invisible.

## Audio format detection

`AVPlayer` decodes everything to either 44.1 kHz or 48 kHz, stereo or
mono, Float32. `SSAudioTap.processBufferList:` auto-detects the
channel count from the `AudioBufferList` on the first callback and
configures `SSSilenceDetector` accordingly. We don't auto-detect the
sample rate because `MTAudioProcessingTap` doesn't expose it directly
— we hard-code 44100 Hz, which is what YouTube uses for everything
except some 48 kHz music videos. The LUFS K-weighting coefficients
for 44.1 kHz and 48 kHz are both baked into `SSLUFS.c`.

If you're porting this to a host that uses a different sample rate,
add the coefficients to `sslufs_init()`.

## Privacy

The tap only *measures* audio loudness. It does not record, transmit,
or persist the audio itself. The only persistent state is:

- `totalSavedSeconds` (double)
- `totalPlayedSeconds` (double)

Both are stored in `NSUserDefaults` on-device and never leave the
device.
