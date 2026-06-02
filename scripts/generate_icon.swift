#!/usr/bin/env swift
// Generates a 1024x1024 CorrectClick app icon and saves it to the given path.
// Usage: swift generate_icon.swift output.png

import AppKit
import CoreGraphics

let size = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

// --- Canvas setup ---
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.saveGState()

// --- Background: rounded rect with indigo→blue gradient ---
let cornerRadius: CGFloat = 220
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let path = CGPath(
    roundedRect: rect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)
ctx.addPath(path)
ctx.clip()

let gradientColors = [
    CGColor(red: 0.27, green: 0.25, blue: 0.90, alpha: 1), // indigo
    CGColor(red: 0.10, green: 0.53, blue: 0.98, alpha: 1)  // bright blue
]
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: gradientColors as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: []
)
ctx.restoreGState()

// --- Draw using NSGraphicsContext so we can use NSImage / NSBezierPath ---
NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx

// Document body: white rounded rectangle
let docW: CGFloat = 340
let docH: CGFloat = 420
let docX: CGFloat = CGFloat(size) / 2 - docW / 2 - 30
let docY: CGFloat = CGFloat(size) / 2 - docH / 2 + 20
let docCorner: CGFloat = 36

let docRect = NSRect(x: docX, y: docY, width: docW, height: docH)
let docPath = NSBezierPath(roundedRect: docRect, xRadius: docCorner, yRadius: docCorner)

// Slight shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()

NSColor.white.withAlphaComponent(0.95).setFill()
docPath.fill()
NSShadow().set() // clear shadow

// Folded corner (dog-ear)
let foldSize: CGFloat = 70
let foldPath = NSBezierPath()
foldPath.move(to: NSPoint(x: docX + docW - foldSize, y: docY + docH))
foldPath.line(to: NSPoint(x: docX + docW, y: docY + docH - foldSize))
foldPath.line(to: NSPoint(x: docX + docW - foldSize, y: docY + docH - foldSize))
foldPath.close()
NSColor(red: 0.10, green: 0.53, blue: 0.98, alpha: 0.35).setFill()
foldPath.fill()

// Lines on the document (text representation)
NSColor(red: 0.75, green: 0.80, blue: 0.88, alpha: 1).setFill()
let lineHeight: CGFloat = 18
let lineSpacing: CGFloat = 32
let lineX = docX + 44
let lineStartY = docY + docH - 130
let lineLengths: [CGFloat] = [200, 220, 160, 210, 180, 130]
for (i, lineLen) in lineLengths.enumerated() {
    let lineY = lineStartY - CGFloat(i) * lineSpacing
    let lineRect = NSRect(x: lineX, y: lineY, width: lineLen, height: lineHeight)
    NSBezierPath(roundedRect: lineRect, xRadius: 9, yRadius: 9).fill()
}

// Plus badge circle (bottom-right of document)
let badgeR: CGFloat = 115
let badgeCX = docX + docW + 8
let badgeCY = docY - 8
let badgeRect = NSRect(x: badgeCX - badgeR, y: badgeCY - badgeR, width: badgeR * 2, height: badgeR * 2)

// Badge shadow
let badgeShadow = NSShadow()
badgeShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
badgeShadow.shadowBlurRadius = 22
badgeShadow.shadowOffset = NSSize(width: 0, height: -6)
badgeShadow.set()

NSColor(red: 0.18, green: 0.85, blue: 0.55, alpha: 1).setFill() // green
NSBezierPath(ovalIn: badgeRect).fill()
NSShadow().set()

// Plus symbol
NSColor.white.setFill()
let plusThickness: CGFloat = 22
let plusLen: CGFloat = 72
let hBar = NSRect(x: badgeCX - plusLen/2, y: badgeCY - plusThickness/2, width: plusLen, height: plusThickness)
let vBar = NSRect(x: badgeCX - plusThickness/2, y: badgeCY - plusLen/2, width: plusThickness, height: plusLen)
NSBezierPath(roundedRect: hBar, xRadius: plusThickness/2, yRadius: plusThickness/2).fill()
NSBezierPath(roundedRect: vBar, xRadius: plusThickness/2, yRadius: plusThickness/2).fill()

NSGraphicsContext.restoreGraphicsState()

// --- Write PNG ---
let image = ctx.makeImage()!
let bitmapRep = NSBitmapImageRep(cgImage: image)
let pngData = bitmapRep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
