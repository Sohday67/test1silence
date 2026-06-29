# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Voice Boost EQ + look-ahead limiter implementation
- Real `OCAudioClassifier`-style music detector
- Localizations (es, fr, de, ja, zh-Hans)

## [1.0.0] — 2026-06-28

### Added
- Initial release.
- LUFS loudness measurement per ITU-R BS.1770-4 (`SSLUFS.c`).
- `voice_boost_t`-compatible state struct (`SSVoiceBoostState`) with
  the same field layout recovered from Overcast's binary.
- Real-time silence detector (`SSSilenceDetector`) with 2-pass
  loudness tracking (running average + short-term peak).
- `MTAudioProcessingTap` installer (`SSAudioTap`) that hooks into
  YouTube's `AVPlayerItem` audio mix.
- Smart Speed controller (`SSSmartSpeedController`) that drives
  `AVPlayer.rate` during silent regions and accumulates time-saved
  statistics.
- Logos hooks (`Tweak.x`) on `AVPlayer` and `YTPlayerViewController`
  to attach the controller on playback start.
- PreferenceLoader bundle (`SkipSilencePrefs`) with YouTube-red
  switch cells, sliders for skip speed / threshold / duration /
  Voice Boost target LUFS, and lifetime-stats display.
- Reverse-engineering write-up (`OvercastAnalysis.md`) documenting
  the recovered `voice_boost_t` struct, the ObjC method surface,
  the C symbols (`lufs_process_chunk`, `premeasured_lufs`,
  `kVBTargetLUFSAnalyzeOnly`), and the algorithm summary.

### Notes
- No code, assets, or resources from the Overcast binary are
  included. Only the algorithm (an open ITU-R BS.1770-4 standard)
  and the recovered struct layout (not subject to copyright) are
  reused for interoperability.
