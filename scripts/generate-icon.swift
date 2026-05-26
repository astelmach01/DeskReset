import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "dist/DeskReset.app/Contents/Resources/AppIcon.icns"
let outputURL = URL(fileURLWithPath: output)
let iconsetURL = outputURL.deletingLastPathComponent().appendingPathComponent("AppIcon.iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let baseSize = 1024
let base = NSImage(size: NSSize(width: baseSize, height: baseSize))
base.lockFocus()

let rect = NSRect(x: 0, y: 0, width: baseSize, height: baseSize)
NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1).setFill()
rect.fill()

let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: 74, dy: 74), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.34, green: 0.76, blue: 0.71, alpha: 1)
])
gradient?.draw(in: backgroundPath, angle: 35)

NSColor.white.withAlphaComponent(0.22).setStroke()
backgroundPath.lineWidth = 18
backgroundPath.stroke()

let inner = NSBezierPath(roundedRect: rect.insetBy(dx: 190, dy: 190), xRadius: 150, yRadius: 150)
NSColor.white.withAlphaComponent(0.19).setFill()
inner.fill()

let figureRect = NSRect(x: 272, y: 246, width: 480, height: 520)
if let figure = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil) {
    figure.lockFocus()
    NSColor.white.set()
    figure.unlockFocus()
    figure.draw(in: figureRect, from: .zero, operation: .sourceOver, fraction: 0.96)
}

let eyePath = NSBezierPath(ovalIn: NSRect(x: 350, y: 310, width: 324, height: 84))
NSColor.white.withAlphaComponent(0.86).setStroke()
eyePath.lineWidth = 26
eyePath.stroke()

let dotPath = NSBezierPath(ovalIn: NSRect(x: 485, y: 329, width: 54, height: 54))
NSColor.white.setFill()
dotPath.fill()

base.unlockFocus()

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    base.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: rect, operation: .copy, fraction: 1)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(name)")
    }
    try png.write(to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

try? fileManager.removeItem(at: iconsetURL)
print(outputURL.path)
