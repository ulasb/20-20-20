// Renders the app icon (white eye on a teal gradient squircle) at every size
// macOS wants, into an .iconset folder for iconutil.
//   swift tools/makeicon.swift <output.iconset>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(canvas: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
        // Standard macOS icon margin: artwork sits inset on the 1024 grid
        let box = rect.insetBy(dx: rect.width * 0.09, dy: rect.height * 0.09)
        let path = NSBezierPath(
            roundedRect: box,
            xRadius: box.width * 0.2237,
            yRadius: box.height * 0.2237
        )

        if canvas >= 64 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = NSSize(width: 0, height: -rect.height * 0.012)
            shadow.shadowBlurRadius = rect.height * 0.02
            NSGraphicsContext.current?.saveGraphicsState()
            shadow.set()
            NSColor.black.setFill()
            path.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        NSGradient(colors: [
            NSColor(calibratedHue: 0.53, saturation: 0.55, brightness: 0.58, alpha: 1),
            NSColor(calibratedHue: 0.62, saturation: 0.60, brightness: 0.20, alpha: 1),
        ])!.draw(in: path, angle: -90)

        let config = NSImage.SymbolConfiguration(pointSize: box.width * 0.45, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return true }
        let white = NSImage(size: symbol.size, flipped: false) { symbolRect in
            symbol.draw(in: symbolRect)
            NSColor.white.set()
            symbolRect.fill(using: .sourceAtop)
            return true
        }

        let width = box.width * 0.58
        let height = width * symbol.size.height / symbol.size.width
        white.draw(in: NSRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        ))
        return true
    }
}

func savePNG(_ image: NSImage, pixels: Int, to path: String) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("could not create bitmap rep") }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let suffix = scale == 2 ? "@2x" : ""
        savePNG(drawIcon(canvas: CGFloat(pixels)), pixels: pixels,
                to: "\(outDir)/icon_\(size)x\(size)\(suffix).png")
    }
}
print("Wrote iconset to \(outDir)")
