# Resources

This directory holds assets that get bundled into `SkipSilencePrefs.bundle`.

- `icon.png` — 58×58 px icon shown next to the "Skip Silence" entry in
  Settings → YTLite. Use `icon@2x.png` (116×116) for retina.
- `icon.svg` — source SVG for the icon. Convert with:
  ```bash
  # Requires rsvg-convert or Inkscape
  rsvg-convert -w 116 -h 116 icon.svg > icon@2x.png
  rsvg-convert -w 58  -h 58  icon.svg > icon.png
  ```

The icon design is a red rounded square (matching YouTube's brand
color) with a white speaker + skip-arrow glyph.
