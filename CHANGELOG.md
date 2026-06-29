# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Voice Boost EQ + look-ahead limiter implementation
- Real `OCAudioClassifier`-style music detector
- Localizations (es, fr, de, ja, zh-Hans)

## [1.0.1] — 2026-06-29

### Fixed
- **Build failure: nullability completeness** — `SSSilenceDetector.h`'s
  `processPlanarSamples:` parameter (`const float *const *`) needed
  explicit nullability annotations. Added `_Nullable` annotations to
  both pointer levels.
- **Build failure: MTAudioProcessingTapCallbacks field names** — the
  struct uses `init`, `finalize`, `prepare`, `process`, `unprepare`
  (no `tap` prefix). Corrected in `SSAudioTap.m`.
- **Build failure: MTAudioProcessingTapRelease does not exist** —
  `MTAudioProcessingTapRef` is a CFType, so the correct release call
  is `CFRelease()`. Fixed in `SSAudioTap.m`.
- **Build failure: unknown selector `setRate:withTime:atHostTime:`** —
  this is a private API on `AVPlayer`. Replaced with the public
  `rate` property setter in `SSSmartSpeedController.m`. The
  ~50 ms granularity is fine for silence skipping.
- **Build failure: duplicate method declarations in SSPrefs.m** —
  the `SS_PROP_SET` macro expanded every setter to `setName:`. Rewrote
  `SSPrefs.m` with explicit accessor pairs for all 12 properties.
- **Build failure: SSPrefsRootController.m** — `PSListController` has
  no `initWithSpecifiers:` initializer and the manual specifier
  construction was broken. Rewrote to use the standard Theos pattern
  (`loadSpecifiersFromPlistName:@"Root" target:self` in the `specifiers`
  getter).
- **Build failure: SSPrefsSwitchCell.m** — `switchControl` is not a
  property of `PSTableCell`. Use the `control` property from
  `PSControlTableCell` (the parent class) and downcast to `UISwitch`.
- **Build failure: missing UIKit import in Tweak.x** —
  `YTPlayerViewController` forward declaration needed `UIViewController`
  from UIKit. Added the import.
- **Build failure: PreferenceLoader bundle resources** — added a
  proper `Resources/Info.plist` and copied `Root.plist` into
  `Resources/` so Theos auto-detects and bundles them.
- **MobileSubstrate filter format** — removed non-standard
  `ArchiveSupplier`, `SupplierInfo`, and `Mode` keys from
  `SkipSilenceYT.plist`. The standard filter is just `Filter = { Bundles = (...) }`.
- **Makefile** — fixed the `SkipSilenceYii_FRAMEWORKS` typo,
  removed the bogus `SkipSilencePrefs_BUNDLE_RESOURCE_DIR` variable,
  added the `Preferences` private framework path to the prefs bundle
  CFLAGS, and converted the `after-stage::` recipe lines from spaces
  to tabs.

### Added
- `Resources/Info.plist` for the preferences bundle (required by
  PreferenceLoader to instantiate `SSPrefsRootController`).

### Verified
- The project now builds cleanly with Theos + iPhoneOS14.5 SDK on
  Linux x86_64 using the L1ghtmann iOSToolchain. The output
  `.deb` (`com.ytlite.skipsilence_1.0.0_iphoneos-arm.deb`) contains
  the tweak dylib (200 KB), the MobileSubstrate filter plist, the
  preferences bundle (binary + Info.plist + Root.plist + icon.svg),
  and the PreferenceLoader entry plist.

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
