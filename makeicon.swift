// Generates AppIcon.icns for DistanceCalculator: a macOS-style rounded
// square with a blue gradient, a dashed route, and two location pins.
// Run via build.sh; requires only AppKit and the iconutil/sips CLIs.
import AppKit

let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Rounded-rect background (macOS Big Sur style: ~22.5% corner radius,
// icon artwork inset ~10% from the canvas edge).
let inset: CGFloat = size * 0.10
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

// Subtle drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.008), blur: size * 0.02,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.white.setFill()
bg.fill()
ctx.restoreGState()

// Blue gradient fill
bg.addClip()
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.05, green: 0.28, blue: 0.75, alpha: 1),
])!
gradient.draw(in: rect, angle: -90)

// Dashed route curve between the two pin positions
let start = CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.26)
let end = CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.62)
let route = NSBezierPath()
route.move(to: start)
route.curve(to: end,
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.62),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.60, y: rect.minY + rect.height * 0.30))
route.lineWidth = size * 0.028
route.lineCapStyle = .round
route.setLineDash([size * 0.001, size * 0.06], count: 2, phase: 0)
NSColor.white.withAlphaComponent(0.9).setStroke()
route.stroke()

// Map pin: teardrop with a hole, drawn at a given tip point and height.
func drawPin(tip: CGPoint, height: CGFloat, color: NSColor, hole: NSColor) {
    let r = height * 0.36              // head radius
    let center = CGPoint(x: tip.x, y: tip.y + height - r)
    let pin = NSBezierPath()
    // Circle head with a wedge down to the tip
    pin.appendArc(withCenter: center, radius: r, startAngle: -50, endAngle: 230)
    pin.line(to: tip)
    pin.close()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -height * 0.03), blur: height * 0.06,
                  color: NSColor.black.withAlphaComponent(0.3).cgColor)
    color.setFill()
    pin.fill()
    ctx.restoreGState()
    let holePath = NSBezierPath(ovalIn: CGRect(x: center.x - r * 0.42, y: center.y - r * 0.42,
                                               width: r * 0.84, height: r * 0.84))
    hole.setFill()
    holePath.fill()
}

// Origin dot (start) and destination pin (end)
let dotR = rect.height * 0.055
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.006), blur: size * 0.015,
              color: NSColor.black.withAlphaComponent(0.3).cgColor)
NSColor.white.setFill()
NSBezierPath(ovalIn: CGRect(x: start.x - dotR, y: start.y - dotR,
                            width: dotR * 2, height: dotR * 2)).fill()
ctx.restoreGState()
NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.85, alpha: 1).setFill()
NSBezierPath(ovalIn: CGRect(x: start.x - dotR * 0.45, y: start.y - dotR * 0.45,
                            width: dotR * 0.9, height: dotR * 0.9)).fill()

drawPin(tip: end, height: rect.height * 0.30,
        color: NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.25, alpha: 1),
        hole: .white)

image.unlockFocus()

// Write 1024px PNG
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to encode PNG")
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
