# Contributing to ytlite-skip-silence

Thanks for your interest in improving this project! Before opening a
PR, please:

## 1. Open an issue first

For any non-trivial change (new feature, refactor of the audio
pipeline, change to the LUFS algorithm), please open an issue
describing what you want to build and why. This avoids duplicated
work and ensures the change fits the project's scope.

## 2. Match the existing style

- C/ObjC: 4-space indent, K&R braces, `ss_` prefix for C functions,
  `SS` prefix for ObjC classes.
- Logos hooks: keep `%hook` blocks small and focused on one class.
- Property accessors in `SSPrefs.m`: use the `SS_PROP_GET_*` /
  `SS_PROP_SET_*` macros so all keys go through `NSUserDefaults`
  consistently.

## 3. Test on real hardware

The LUFS detector only runs in real time when YouTube is actually
playing audio. Test on a jailbroken device with:

- YouTube (latest App Store version, decrypted)
- YTLite 5.0 or later
- iOS 14 or later (rootless preferred)

Make sure the "Time Saved" stat in Settings → YTLite → Skip Silence
increases when you play a video with significant silent sections
(e.g. a long-form interview with pauses).

## 4. Sign the contributor license agreement

By submitting a pull request, you agree that your contribution is
licensed under the project's MIT license and that you have the right
to contribute it. Contributions that include code copied from the
Overcast binary (or any other proprietary source) will be rejected.

## 5. Areas that need help

- **Music detection classifier** — Overcast uses `OCAudioClassifier`
  to detect music and bypass Smart Speed. A real implementation
  needs spectral feature extraction (FFT → centroid, flux, rolloff)
  and a simple classifier (SVM or threshold rules). The hook point
  is `SSSilenceDetector.musicDetectionBypass`.

- **Voice Boost EQ + limiter** — The LUFS measurement infrastructure
  is already in place. Voice Boost needs a parametric EQ (high-pass
  at 80 Hz, presence boost at 3 kHz) followed by a look-ahead
  limiter targeting `voiceBoostTargetLUFS`. See
  `SSVoiceBoostState.h` for the recovered struct layout.

- **Localization** — All UI strings are English-only. PreferenceLoader
  supports `.strings` files alongside `Root.plist`.

- **Rootless packaging** — The Makefile has the rootless build path,
  but it hasn't been tested against the latest Sileo. PRs that fix
  any rootless packaging issues are very welcome.
