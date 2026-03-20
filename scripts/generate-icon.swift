#!/usr/bin/env swift

// Generates a microphone-themed app icon at multiple sizes.
// Usage: swift scripts/generate-icon.swift

import AppKit
import Foundation

func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let padding = size * 0.08
    let innerRect = rect.insetBy(dx: padding, dy: padding)

    // Background: rounded square with gradient (dark blue to purple)
    let cornerRadius = size * 0.22
    let path = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors: [CGColor] = [
        CGColor(red: 0.15, green: 0.10, blue: 0.35, alpha: 1.0),  // Deep purple
        CGColor(red: 0.08, green: 0.08, blue: 0.25, alpha: 1.0),  // Dark blue
    ]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
            start: CGPoint(x: size/2, y: size - padding),
            end: CGPoint(x: size/2, y: padding),
            options: [])
    }

    // Microphone body (rounded rect)
    let micWidth = size * 0.22
    let micHeight = size * 0.32
    let micX = (size - micWidth) / 2
    let micY = size * 0.42
    let micRect = CGRect(x: micX, y: micY, width: micWidth, height: micHeight)
    let micPath = CGPath(roundedRect: micRect, cornerWidth: micWidth/2, cornerHeight: micWidth/2, transform: nil)
    
    // Mic glow effect
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.06, color: CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.6))
    ctx.setFillColor(CGColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1.0))
    ctx.addPath(micPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Mic grille lines
    let lineCount = 3
    let lineSpacing = micHeight * 0.15
    let lineStartY = micY + micHeight * 0.3
    ctx.setStrokeColor(CGColor(red: 0.6, green: 0.65, blue: 0.8, alpha: 0.4))
    ctx.setLineWidth(max(1, size * 0.012))
    for i in 0..<lineCount {
        let y = lineStartY + CGFloat(i) * lineSpacing
        let inset = size * 0.04
        ctx.move(to: CGPoint(x: micX + inset, y: y))
        ctx.addLine(to: CGPoint(x: micX + micWidth - inset, y: y))
        ctx.strokePath()
    }

    // Mic holder arc
    let arcCenterX = size / 2
    let arcY = micY - size * 0.01
    let arcRadius = micWidth * 0.75
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 0.9))
    ctx.setLineWidth(max(1.5, size * 0.025))
    ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: arcCenterX, y: arcY), radius: arcRadius,
               startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
    ctx.strokePath()

    // Stand line
    let standTop = arcY - arcRadius * sin(.pi * 0.5) + size * 0.01
    let standBottom = standTop - size * 0.1
    ctx.move(to: CGPoint(x: arcCenterX, y: standTop))
    ctx.addLine(to: CGPoint(x: arcCenterX, y: standBottom))
    ctx.strokePath()

    // Stand base
    let baseWidth = size * 0.16
    ctx.move(to: CGPoint(x: arcCenterX - baseWidth/2, y: standBottom))
    ctx.addLine(to: CGPoint(x: arcCenterX + baseWidth/2, y: standBottom))
    ctx.strokePath()

    // Subtle sound waves (right side)
    ctx.setStrokeColor(CGColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.3))
    ctx.setLineWidth(max(1, size * 0.015))
    for i in 1...3 {
        let waveRadius = size * 0.06 * CGFloat(i)
        let waveCenterX = size / 2 + micWidth / 2 + size * 0.02
        let waveCenterY = micY + micHeight / 2
        ctx.addArc(center: CGPoint(x: waveCenterX, y: waveCenterY), radius: waveRadius,
                   startAngle: -.pi * 0.3, endAngle: .pi * 0.3, clockwise: false)
        ctx.strokePath()
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✅ \(path)")
    } catch {
        print("❌ Failed to write \(path): \(error)")
    }
}

// Generate all required sizes
let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = "Resources/Assets.xcassets/AppIcon.appiconset"

for size in sizes {
    let image = generateIcon(size: CGFloat(size))
    savePNG(image, to: "\(outputDir)/icon_\(size).png")
}

// Also generate an .icns file for the DMG
func generateICNS(from images: [(Int, NSImage)], to path: String) {
    // Use iconutil by first creating an iconset
    let iconsetPath = "/tmp/Whispr.iconset"
    let fm = FileManager.default
    try? fm.removeItem(atPath: iconsetPath)
    try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    let iconsetSizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for (name, size) in iconsetSizes {
        if let (_, img) = images.first(where: { $0.0 == size }) {
            savePNG(img, to: "\(iconsetPath)/\(name)")
        }
    }

    // Convert to icns
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath, "-o", path]
    try! process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("✅ \(path)")
    } else {
        print("❌ iconutil failed")
    }

    try? fm.removeItem(atPath: iconsetPath)
}

let allImages = sizes.map { (size: $0, image: generateIcon(size: CGFloat($0))) }
let mappedImages = allImages.map { ($0.size, $0.image) }

try? FileManager.default.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
generateICNS(from: mappedImages, to: "Resources/AppIcon.icns")

print("\n🎨 Icon generation complete!")
