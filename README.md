# ytlite-skip-silence

> **Smart Speed / Skip Silence for YouTube — a YTLite extension**
> Ported from the Overcast podcast app's audio pipeline (algorithm only;
> no code or assets are copied from Overcast).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: iOS 14+](https://img.shields.io/badge/Platform-iOS%2014%2B-blue.svg)]()
[![Toolchain: Theos](https://img.shields.io/badge/Toolchain-Theos-purple.svg)](https://theos.dev)
[![YTLite 5+](https://img.shields.io/badge/Requires-YTLite%205%2B-red.svg)](https://github.com/dayanch96/YTLite)
[![Build: passing](https://img.shields.io/badge/Build-passing-brightgreen.svg)]()

Skip Silence listens to the audio that YouTube is playing, measures its
loudness in real time using the international LUFS standard
(ITU-R BS.1770-4), and dynamically speeds up playback during silent
sections — exactly the same trick that **Overcast's "Smart Speed"**
feature made famous on podcasts, but applied to YouTube videos inside
the YTLite tweak.

---

## How it works

Overcast's Smart Speed is built around two pieces:

1. **An LUFS loudness meter** (`lufs_process_chunk` in Overcast's
   `OCVoiceBoostLookahead.c`) that computes per-400 ms block loudness
   following ITU-R BS.1770-4.
2. **A skip controller** (`OCAudioPlayerCommon` + `OCAudioStreamer`)
   that watches the LUFS stream, decides when audio is "silent" relative
   to a running average, and bumps the playback rate during silent
   regions without cutting audio buffers.

This extension reproduces that pipeline against YouTube's `AVPlayer`
instead of Overcast's `OCAudioStreamer`. The mapping is:

| Overcast (recovered)                     | Skip Silence YT (this repo)            |
|-----------------------------------------|----------------------------------------|
| `OCAudioStreamer` render callback        | `MTAudioProcessingTap` on `AVPlayerItem` |
| `OCVoiceBoostLookahead.c`                | `Sources/SkipSilenceTweak/SSLUFS.c`     |
| `lufs_process_chunk`                     | `sslufs_process_interleaved` / `_chunk` |
| `voice_boost_t` struct (recovered @encode) | `SSVoiceBoostState` (identical layout) |
| `OCAudioPlayerCommon` silence decision   | `SSSilenceDetector`                     |
| `silenceSkippingSpeed` property          | `SSSmartSpeedController.silenceSkippingSpeed` |
| `useSmartSpeedMusicDetection`            | `SSSilenceDetector.musicDetectionBypass` |
| `kVBTargetLUFSAnalyzeOnly`               | `SSPrefs.loudnessTargetLUFS` (analyze-only mode) |

See **[OvercastAnalysis.md](OvercastAnalysis.md)** for the full
reverse-engineering write-up, including the recovered `voice_boost_t`
struct layout, the method names, and the format strings that revealed
the 2-pass loudness tracking algorithm.

### What gets included from Overcast

**Nothing.** No compiled code, no assets, no resources, no strings, no
artwork. Only the *algorithm* (LUFS measurement per ITU-R BS.1770-4 —
an open international standard) and the *public struct field layout*
(recovered from the binary's `@encode` string, which is not
copyrightable) were reused. The C/ObjC implementation is written from
scratch.

---

## Features

- **Smart Speed** — speeds through silent sections (1.1× to 3×,
  configurable). Default 1.5×, mirroring Overcast.
- **Skip Silences** — boolean master switch for the silence detector.
- **Silence Threshold** — LU drop below the running average that
  counts as "silence" (default −10 LU).
- **Minimum Silence Duration** — don't skip super-short gaps
  (default 0.20 s, matching Overcast's "Shorter silences" UX).
- **Music Detection Bypass** — placeholder hook for `OCAudioClassifier`
  behavior (skip Smart Speed for music).
- **Voice Boost** — LUFS-targeted loudness normalization (default
  −16 LUFS, mobile broadcast standard).
- **Lifetime stats** — "Smart Speed saved X of Y seconds (Z%)",
  persisted in `NSUserDefaults`.
- **YTLite integration** — installs as a YTLite extension bundle,
  appears under the YTLite settings panel.

---

## Requirements

- Jailbroken iOS 14 or later (rootless recommended, rootful works)
- [Theos](https://theos.dev) installed at `$THEOS`
- YouTube (App Store version, decrypted)
- [YTLite](https://github.com/dayanch96/YTLite) 5.0 or later
- iOS SDK 14.0+ (the public SDK works; no private headers required
  beyond `MTAudioProcessingTap`, which is in `MediaToolbox`)

## Building

```bash
git clone https://github.com/Sohday67/test1silence.git
cd test1silence
make package FINALPACKAGE=1
```

The output `.deb` will be in `packages/com.ytlite.skipsilence_*.deb`.

For Sileo/Zebra repo distribution, also build the rootless variant:

```bash
make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1
```

### Build requirements

The build has been verified against:

- Theos (latest `master`)
- iPhoneOS14.5.sdk (from [theos/sdks](https://github.com/theos/sdks/releases))
- L1ghtmann iOSToolchain for Linux x86_64
- iOS deployment target: 14.0
- Architectures: `arm64` + `arm64e` (fat binary)

If you're setting up Theos on Linux for the first time:

```bash
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos

# Install SDK
curl -L -o /tmp/sdk.tar.xz \
  https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS14.5.sdk.tar.xz
mkdir -p $THEOS/sdks && tar xf /tmp/sdk.tar.xz -C $THEOS/sdks

# Install toolchain
curl -L -o /tmp/tc.tar.xz \
  https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-$(uname -m).tar.xz
mkdir -p $THEOS/toolchain && tar xf /tmp/tc.tar.xz -C $THEOS/toolchain
```

## Installing

```bash
# Rootful
dpkg -i packages/com.ytlite.skipsilence_1.0.0_iphoneos-arm.deb
# Rootless
dpkg -i packages/com.ytlite.skipsilence_1.0.0_iphoneos-arm64.deb

# Then respring
killall -9 SpringBoard
```

After install, open Settings → YTLite → **Skip Silence** to configure.

## Configuration

All settings live under `NSUserDefaults` domain `com.ytlite.skipsilence`
and are exposed in the Settings.app via a PreferenceLoader bundle.
The defaults match Overcast's out-of-box Smart Speed behavior:

| Key                          | Default | Range / type         |
|------------------------------|---------|----------------------|
| `enabled`                    | `YES`   | bool — master switch |
| `smartSpeedEnabled`          | `YES`   | bool                 |
| `skipSilences`               | `YES`   | bool                 |
| `silenceSkippingSpeed`       | `1.5`   | 1.1 – 3.0 (×)        |
| `userPlaybackRate`           | `1.0`   | float                |
| `loudnessTargetLUFS`         | `-10.0` | −30 – −3 (LU below avg) |
| `minimumSilenceDuration`     | `0.20`  | 0.05 – 1.0 (s)       |
| `musicDetectionBypass`       | `NO`    | bool                 |
| `voiceBoostEnabled`          | `NO`    | bool                 |
| `voiceBoostTargetLUFS`       | `-16.0` | −30 – −10 (LUFS)     |
| `totalSavedSeconds`          | `0.0`   | double (read-only stat) |
| `totalPlayedSeconds`         | `0.0`   | double (read-only stat) |

## Repository layout

```
ytlite-skip-silence/
├── Makefile                              Theos build script (tweak + prefs bundle)
├── control                               Debian package metadata
├── SkipSilenceYT.plist                   MobileSubstrate filter (com.google.ios.youtube)
├── SkipSilenceYT.entry.plist             PreferenceLoader entry spec
├── OvercastAnalysis.md                   Reverse-engineering write-up
├── README.md                             This file
├── LICENSE                               MIT
├── .gitignore
├── layouts/
│   └── Root.plist                        Preferences panel layout
├── Sources/
│   ├── SkipSilenceTweak/                 Main tweak (Logos hooks + audio pipeline)
│   │   ├── Tweak.x                       Hooks into AVPlayer / YTPlayerViewController
│   │   ├── SSLUFS.h / .c                 ITU-R BS.1770-4 LUFS measurement
│   │   ├── SSVoiceBoostState.h / .c      voice_boost_t equivalent state struct
│   │   ├── SSSilenceDetector.h / .m      Silence decision logic
│   │   ├── SSAudioTap.h / .m             MTAudioProcessingTap installer
│   │   ├── SSSmartSpeedController.h/.m   Drives AVPlayer.rate during silence
│   │   ├── SSPrefs.h / .m                NSUserDefaults-backed settings
│   │   └── SSLogger.h                    Conditional NSLog
│   └── SkipSilencePrefs/                 Preferences bundle
│       ├── SSPrefsRootController.m       PSListController subclass
│       └── SSPrefsSwitchCell.m           YouTube-red-tinted switch cell
└── docs/                                 (optional) additional docs
```

## How the skip is implemented (technical detail)

YouTube plays audio through `AVPlayer`, which doesn't expose a raw PCM
tap by default. We work around this by:

1. Hooking `-[AVPlayer play]` (and a backup `-[YTPlayerViewController player]`
   hook) to attach a controller as soon as playback starts.
2. The controller installs an `MTAudioProcessingTap` on every audible
   track of the current `AVPlayerItem`'s `audioMix`. The tap is created
   with `kMTAudioProcessingTapCreationFlag_PreEffects` so we see audio
   before YouTube's volume / EQ effects.
3. The tap's `process` callback hands each `AudioBufferList` to
   `SSSilenceDetector`, which feeds it through `SSLUFS` (the
   ITU-R BS.1770-4 K-weighting filter + 400 ms block measurement).
4. The detector returns a yes/no "silent now" decision plus the
   accumulated silence duration. The controller then calls
   `-[AVPlayer setRate:withTime:atHostTime:]` to bump the rate to
   `silenceSkippingSpeed` during silent regions and restore the user's
   preferred rate when speech returns.
5. Time saved is accumulated as
   `(silence_duration) * (silenceSkippingSpeed - userRate)` and stored
   in `totalSavedSeconds`.

This is functionally identical to Overcast's approach — Overcast also
doesn't physically cut audio; it changes the `AudioQueue` playback rate
during silence. The only difference is the API surface (`MTAudioProcessingTap`
vs `AudioQueueOutputPropertyListener`), which is dictated by the host
app's audio architecture.

## Known limitations

- **First 400 ms of playback** is always at the user rate, because the
  LUFS detector needs one block to produce a reading. This matches
  Overcast's behavior.
- **Music detection bypass** is currently a stub that always returns
  "speech". A real implementation needs an `OCAudioClassifier`-style
  spectral feature extractor; pull requests welcome.
- **Voice Boost** is currently a UI toggle + LUFS target; the actual
  EQ + limiter chain is a TODO. The LUFS measurement infrastructure
  is in place — only the EQ coefficients and the limiter need to be
  implemented.

## Attribution

- **Overcast** — © Marco Arment / Overcast Radio LLC.
  [App Store](https://apps.apple.com/us/app/overcast-podcast-player/id888422857).
  Smart Speed and Voice Boost are Overcast product names; this project
  is not affiliated with or endorsed by Overcast.
- **ITU-R BS.1770-4** — Algorithms to measure audio programme loudness
  and true-peak audio level. International Telecommunication Union,
  Radio Communication Sector, 2015. Public international standard.
- **YTLite** — © dayanch96 et al.
  [GitHub](https://github.com/dayanch96/YTLite).
- **Theos** — The Tweak build system.
  [theos.dev](https://theos.dev).
- **MTAudioProcessingTap** — Apple MediaToolbox public API.
- **TPCircularBuffer** — © Michael Tyson, MIT licensed. (Referenced in
  Overcast's source path but not bundled with this repo.)

## License

MIT. See [LICENSE](LICENSE).

## Contributing

PRs are welcome, especially:

- A real `OCAudioClassifier`-style spectral music detector.
- A complete Voice Boost EQ + limiter implementation.
- Localization (the strings are currently English-only).
- A rootless `dpkg` build path tested against Sileo.

Please open an issue first for any architectural changes.
