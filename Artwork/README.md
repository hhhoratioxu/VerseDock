# VerseDock 图标

![VerseDock icon](VerseDock-Icon-1024.png)

图标由本次内置 imagegen 生成。主题是浅绿到薄荷色的立体 V，内侧两条圆角线代表歌词，背景沿用 App 的深色调；没有使用 Spotify 标志或下载其他应用的图标。

## 文件

- `VerseDock-Icon-1024.png`：1024 × 1024、不透明、sRGB 主图。
- `../App/Resources/AppIcon.icns`：macOS 图标，包含多尺寸和透明圆角外缘。
- `../App/Resources/Assets.xcassets/AppIcon.appiconset`：iPhone/iPad 的 AppIcon，由 Xcode 生成系统所需尺寸。
- `../App/Resources/BrandMark.png` 与 `BrandMark.imageset`：App 顶部使用的 128 像素图。

Mac 与 iOS 共享同一幅主图。导出仅做尺寸、颜色空间、透明通道和平台图标外缘处理，不改动主图内容。重新导出可执行 `xcrun swift scripts/export-icons.swift "$PWD"`。

## 最终生成提示词

使用内置 image_gen，背景不透明，没有调用需要 API Key 的 CLI。

> Use case: logo-brand. Asset type: production app icon master for VerseDock, an original native Spotify lyrics companion for macOS, iPhone and iPad. Create one polished square 1024 x 1024 icon, not a presentation sheet or a phone mockup. Full-bleed opaque midnight charcoal background (#10151b), with a very subtle cool teal ambient gradient. In the center, a distinctive simple sculptural V glyph made from a broad flowing ribbon, with two short rounded horizontal lyric strokes integrated into its upper opening, conveying verse text and an audio pulse together. The silhouette must remain immediately legible at 24 pixels. Softly beveled satin/glass surface, pale lime green (#b8e894) transitioning delicately toward mint (#69ddb4), restrained highlights and depth, contemporary premium Apple desktop/mobile icon craft. Balanced negative space and generous safe area around the glyph. Face-on, perfectly centered, crisp edges, no perspective. Do not draw an outer rounded-square tile inside the canvas: the artwork must fill an opaque square and the operating system supplies the final mask. No words, no title, no extra initials except the abstract V form, no tiny details, no Spotify logo, no three curved Spotify waves, no copied existing app logo, no watermark.
