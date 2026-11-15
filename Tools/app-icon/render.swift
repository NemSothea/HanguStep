// Renders the HanguStep app icon: white 한 over three faint ascending steps on the teal accent gradient.
// Usage: swift Tools/app-icon/render.swift <out.png> [size]   (default 1024)
// Regenerate the asset catalog with Tools/app-icon/generate.sh.
import AppKit
import CoreText

let args = CommandLine.arguments
guard args.count >= 2 else { fatalError("usage: render.swift <out.png> [size]") }
let size = CGFloat(Double(args.count > 2 ? args[2] : "1024") ?? 1024)
let unit = size / 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!  // icons must be opaque

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

// Background: teal 500 -> teal 700 (HSColor.accent) -> teal 900, top-left to bottom-right.
let gradient = CGGradient(colorsSpace: space, colors: [color(0x14B8A6), color(0x0F766E), color(0x134E4A)] as CFArray,
                          locations: [0, 0.55, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Three ascending steps.
let step = 240 * unit, origin = 152 * unit, radius = 36 * unit
for i in 0..<3 {
    let rect = CGRect(x: origin + CGFloat(i) * step, y: origin, width: step - 14 * unit, height: step * CGFloat(i + 1))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
}
ctx.setFillColor(color(0xFFFFFF, 0.16))
ctx.fillPath()

// 한, centred on its glyph bounds.
let font = CTFontCreateWithName("AppleSDGothicNeo-Heavy" as CFString, 560 * unit, nil)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "한",
    attributes: [.font: font, .foregroundColor: color(0xFFFFFF)]))
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
ctx.textPosition = CGPoint(x: size / 2 - bounds.midX, y: size / 2 + 20 * unit - bounds.midY)
CTLineDraw(line, ctx)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
