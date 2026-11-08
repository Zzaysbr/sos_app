// Run from the repository root: swift scripts/render_app_icons.swift
// The SVG polygon is the single source for iOS/Android raster exports.
import CoreGraphics
import ImageIO
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let svg = try String(contentsOf: root.appendingPathComponent("assets/branding/emergency.svg"), encoding: .utf8)
let regex = try NSRegularExpression(pattern: "points=\"([^\"]+)\"")
guard let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
      let range = Range(match.range(at: 1), in: svg) else { fatalError("Missing icon polygon") }
let points = svg[range].split(separator: " ").map { pair -> CGPoint in
    let values = pair.split(separator: ",").map { Double($0)! }
    return CGPoint(x: values[0], y: values[1])
}
func render(_ size: Int, path: String, rounded: Bool = false) throws {
    let alpha = rounded ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    guard let cg = CGContext(data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue) else {
        fatalError("Unable to create bitmap context")
    }
    cg.setShouldAntialias(true)
    cg.translateBy(x: 0, y: CGFloat(size))
    cg.scaleBy(x: CGFloat(size) / 1024, y: -CGFloat(size) / 1024)
    cg.setFillColorSpace(CGColorSpace(name: CGColorSpace.sRGB)!)
    cg.setFillColor([215/255.0, 38/255.0, 56/255.0, 1])
    let rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    if rounded { cg.addPath(CGPath(roundedRect: rect, cornerWidth: 216, cornerHeight: 216, transform: nil)); cg.fillPath() }
    else { cg.fill(rect) }
    cg.setFillColor([1, 1, 1, 1])
    cg.move(to: points[0])
    for point in points.dropFirst() { cg.addLine(to: point) }
    cg.closePath(); cg.fillPath()
    guard let image = cg.makeImage(),
          let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent(path) as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Unable to export icon")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }

}
try render(1024, path: "assets/branding/emergency-icon.png")
let iconDirectory = "ios/Runner/Assets.xcassets/EmergencyIcon.appiconset/"
let data = try Data(contentsOf: root.appendingPathComponent(iconDirectory + "Contents.json"))
let contents = try JSONSerialization.jsonObject(with: data) as! [String: Any]
var written = Set<String>()
for entry in contents["images"] as! [[String: String]] {
    guard let filename = entry["filename"], written.insert(filename).inserted else { continue }
    let size = Double(entry["size"]!.split(separator: "x")[0])!
    let scale = Double(entry["scale"]!.dropLast())!
    try render(Int(size * scale), path: iconDirectory + filename)
}
for (density, size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    try render(size, path: "android/app/src/main/res/mipmap-" + density + "/ic_launcher.png", rounded: true)
}
print("Exported Emergency E icon: iOS opaque icons, Android legacy icons, shared preview.")
