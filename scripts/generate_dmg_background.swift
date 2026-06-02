#!/usr/bin/env swift
// Generates a 1120x760 DMG background image (@2x for the 560x380 window).
import AppKit
import CoreGraphics

let w = 1120, h = 760
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil, width: w, height: h,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Background gradient: very light grey-blue
let bg1 = CGColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
let bg2 = CGColor(red: 0.88, green: 0.90, blue: 0.95, alpha: 1)
let bgGrad = CGGradient(colorsSpace: colorSpace, colors: [bg1, bg2] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bgGrad,
    start: CGPoint(x: 0, y: h),
    end: CGPoint(x: 0, y: 0),
    options: [])

// Subtle arrow pointing right (drag hint) between the two icon positions
// App icon sits at ~140,185 and Applications folder at ~420,185 (in @1x coords → double for @2x)
NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx

// Arrow
let arrowColor = NSColor(red: 0.55, green: 0.60, blue: 0.70, alpha: 0.7)
arrowColor.setFill()
arrowColor.setStroke()

let arrowY: CGFloat = CGFloat(h) / 2 + 20
let arrowX1: CGFloat = 390
let arrowX2: CGFloat = 730
let arrowThick: CGFloat = 6
let headLen: CGFloat = 28
let headWidth: CGFloat = 22

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: arrowX1, y: arrowY))
arrow.line(to: NSPoint(x: arrowX2 - headLen, y: arrowY))
arrow.lineWidth = arrowThick
arrow.lineCapStyle = .round
arrow.stroke()

// Arrowhead
let head = NSBezierPath()
head.move(to: NSPoint(x: arrowX2, y: arrowY))
head.line(to: NSPoint(x: arrowX2 - headLen, y: arrowY + headWidth))
head.line(to: NSPoint(x: arrowX2 - headLen, y: arrowY - headWidth))
head.close()
arrowColor.setFill()
head.fill()

// "Drag to Applications" label
let paraStyle = NSMutableParagraphStyle()
paraStyle.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 26, weight: .medium),
    .foregroundColor: NSColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1),
    .paragraphStyle: paraStyle,
]
let label = NSAttributedString(string: "Drag to Applications to install", attributes: attrs)
label.draw(in: NSRect(x: 200, y: CGFloat(h)/2 - 90, width: 720, height: 50))

NSGraphicsContext.restoreGraphicsState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
