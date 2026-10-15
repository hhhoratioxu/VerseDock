import AppKit
import Foundation

// Platform asset export only: preserve the generated artwork, resize it, and apply the standard Mac mask.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let master = root.appendingPathComponent("Artwork/VerseDock-Icon-1024.png")
guard let image = NSImage(contentsOf: master), let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      source.width == 1024, source.height == 1024 else {
    fatalError("Expected a 1024 x 1024 icon master at Artwork/VerseDock-Icon-1024.png")
}
let files = FileManager.default
let resources = root.appendingPathComponent("App/Resources", isDirectory: true)
let catalog = resources.appendingPathComponent("Assets.xcassets", isDirectory: true)
let ios = catalog.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let brand = catalog.appendingPathComponent("BrandMark.imageset", isDirectory: true)
let iconset = root.appendingPathComponent("build/VerseDock.iconset", isDirectory: true)
for path in [resources, catalog, ios, brand, iconset] { try files.createDirectory(at: path, withIntermediateDirectories: true) }

func png(size: Int, macMask: Bool = false) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = macMask ? .premultipliedLast : .noneSkipLast
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue)!
    context.interpolationQuality = .high
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    if macMask {
        let inset = CGFloat(size) * 0.0625
        let tile = bounds.insetBy(dx: inset, dy: inset)
        context.addPath(CGPath(roundedRect: tile, cornerWidth: tile.width * 0.223,
            cornerHeight: tile.height * 0.223, transform: nil))
        context.clip()
        context.draw(source, in: tile)
    } else {
        context.setFillColor(CGColor(red: 0.063, green: 0.082, blue: 0.106, alpha: 1))
        context.fill(bounds)
        context.draw(source, in: bounds)
    }
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}
func json(_ value: [String: Any], at url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
let info: [String: Any] = ["author": "xcode", "version": 1]
try json(["info": info], at: catalog.appendingPathComponent("Contents.json"))
try png(size: 1024).write(to: ios.appendingPathComponent("AppIcon-1024.png"))
try json(["images": [["filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
          "info": info], at: ios.appendingPathComponent("Contents.json"))
let brandPNG = png(size: 128)
try brandPNG.write(to: brand.appendingPathComponent("BrandMark.png"))
try brandPNG.write(to: resources.appendingPathComponent("BrandMark.png"))
try json(["images": [["filename": "BrandMark.png", "idiom": "universal"]], "info": info],
         at: brand.appendingPathComponent("Contents.json"))
for size in [16, 32, 128, 256, 512] {
    try png(size: size, macMask: true).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try png(size: size * 2, macMask: true).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try process.run(); process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Exported iOS AppIcon, BrandMark and Mac AppIcon.icns")
