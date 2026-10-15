# VerseDock icon

[简体中文](README.md) · **English**

![VerseDock icon](VerseDock-Icon-1024.png)

The master icon was created with the built-in imagegen tool for this project. A pale-green-to-mint sculptural V contains two rounded lyric strokes on a dark background. No Spotify logo or downloaded app icon was used.

## Files

- `VerseDock-Icon-1024.png`: opaque 1024 × 1024 sRGB master.
- `../App/Resources/AppIcon.icns`: multi-size macOS icon with transparent rounded outer edges.
- `../App/Resources/Assets.xcassets/AppIcon.appiconset`: iPhone/iPad AppIcon; Xcode generates required platform sizes.
- `../App/Resources/BrandMark.png` and `BrandMark.imageset`: in-app brand images. Since 0.1.9 they reuse the 1024-pixel master to avoid blur when enlarged.

Mac and iOS share the master image. Exports only adapt size, color space, alpha channels and platform icon edges without changing the master artwork. Re-export with `xcrun swift scripts/export-icons.swift "$PWD"`.

## Final generation prompt

The built-in image_gen tool was used with an opaque background. No API-key-based CLI was used. The original English prompt follows.

> Use case: logo-brand. Asset type: production app icon master for VerseDock, an original native Spotify lyrics companion for macOS, iPhone and iPad. Create one polished square 1024 x 1024 icon, not a presentation sheet or a phone mockup. Full-bleed opaque midnight charcoal background (#10151b), with a very subtle cool teal ambient gradient. In the center, a distinctive simple sculptural V glyph made from a broad flowing ribbon, with two short rounded horizontal lyric strokes integrated into its upper opening, conveying verse text and an audio pulse together. The silhouette must remain immediately legible at 24 pixels. Softly beveled satin/glass surface, pale lime green (#b8e894) transitioning delicately toward mint (#69ddb4), restrained highlights and depth, contemporary premium Apple desktop/mobile icon craft. Balanced negative space and generous safe area around the glyph. Face-on, perfectly centered, crisp edges, no perspective. Do not draw an outer rounded-square tile inside the canvas: the artwork must fill an opaque square and the operating system supplies the final mask. No words, no title, no extra initials except the abstract V form, no tiny details, no Spotify logo, no three curved Spotify waves, no copied existing app logo, no watermark.
