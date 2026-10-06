#!/usr/bin/env swift
// Turns a square, full-bleed artwork image into a 1024x1024 macOS app icon:
// the artwork is clipped to Apple's rounded-rect icon shape, inset to the
// standard macOS icon grid (an 824x824 shape centred on the 1024 canvas,
// transparent around it), with the usual soft drop shadow underneath.
//
// Usage: swift scripts/make_app_icon.swift scripts/icon_source.jpg scripts/iconbuild/icon_1024.png
// Then run scripts/build_icns.sh to produce every size + the asset catalog.

import AppKit

let args = CommandLine.arguments
guard args.count == 3, let source = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write("Usage: make_app_icon.swift <square-artwork> <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let canvas: CGFloat = 1024
let shapeSize: CGFloat = 824          // Apple's macOS icon grid
let cornerRadius: CGFloat = 185.4     // matches the system icon shape at 824pt
let shapeRect = NSRect(
    x: (canvas - shapeSize) / 2,
    y: (canvas - shapeSize) / 2 + 10, // nudged up slightly so the shadow below balances it
    width: shapeSize,
    height: shapeSize
)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let shape = NSBezierPath(roundedRect: shapeRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Shadow: drawn from a filled copy of the shape, so it sits outside the
// artwork rather than being clipped away with it.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
NSColor.white.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

// Artwork, clipped to the icon shape.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
source.draw(in: shapeRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

let outputURL = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try rep.representation(using: .png, properties: [:])!.write(to: outputURL)
print("Wrote \(outputURL.path)")
