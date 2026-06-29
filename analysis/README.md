# Analysis artifacts

Raw output from the reverse-engineering scripts that produced the
findings in `OvercastAnalysis.md`. Included for reproducibility.

- `silence_strings.txt` — 125 strings extracted from the Overcast
  Mach-O binary's `__cstring` / `__objc_methname` / `__objc_classname`
  sections, filtered by the regex
  `silence|skip.?silent|smart.?speed|lookahead|voice.?boost|LUFS|audio.?tap|MTAudio`.
  These are the strings that revealed the Smart Speed / Voice Boost
  algorithm surface (method names, format strings, property types,
  struct @encode).
- `oc_classes.txt` — all 428 `OC*` Objective-C class names found in
  the binary's `__objc_classlist` section, recovered by parsing the
  class metadata directly (the binary's symbol table is stripped of
  C symbols but retains full ObjC metadata).

## Why no symbol table?

The Overcast binary is stripped of C symbols — `nm` and `lief` both
return only 2 named symbols (the `_OBJC_METACLASS_$_NSObject` and
`_OBJC_CLASS_$_NSObject` re-exports). All other class / method /
property information was recovered by parsing the `__objc_classlist`,
`__objc_methname`, `__objc_classname`, `__objc_methtype`, and
`__objc_propname` sections directly with `lief` + `capstone`. The
Python scripts that do this live in `/home/z/my-project/scripts/` and
are not bundled in the GitHub repo (they're internal analysis
tooling).

## Reproducing the analysis

If you want to re-derive the findings:

```bash
# 1. Extract the IPA
unzip fm.overcast.overcast_2026.5_und3fined.ipa -d Overcast_extracted
cd Overcast_extracted/Payload/Overcast.app

# 2. Pull all readable strings
strings -n 5 Overcast > strings.txt

# 3. Filter for silence / LUFS / voice boost / smart speed
grep -iE 'silence|smart.?speed|voice.?boost|LUFS|MTAudio|audioproc' strings.txt \
    > silence_strings.txt

# 4. (Optional) Parse the ObjC class list with lief + capstone
python3 -c '
import lief
b = lief.MachO.parse("Overcast")[0]
for sec in b.sections:
    if sec.name == "__objc_methname":
        content = bytes(sec.content)
        for s in content.split(b"\x00"):
            if s and b"silence" in s.lower():
                print(s.decode("utf-8", errors="replace"))
'
```

The struct layout for `voice_boost_t` was recovered from the
`@encode` string `^{voice_boost_t=IIBBBBBBBffq^{?}^{?}^{?}^{?}^{?}^{?}^{?}^{?}ffiB^^{?}i}`,
which appears in the `__objc_const` section as a method signature
for `[OCAudioPlayerCommon inQueue_preprocessVoiceBoostWithStreamer:...]`.
