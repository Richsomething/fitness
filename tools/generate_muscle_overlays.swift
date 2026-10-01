import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let canvasWidth = 1024
private let canvasHeight = 1536
private let midX: CGFloat = 512

private struct MusclePart {
    let side: String?
    let points: [CGPoint]
}

private struct MuscleGroup {
    let slug: String
    let title: String
    let parts: [MusclePart]
}

private func points(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] {
    values.map(CGPoint.init)
}

private func mirrored(_ source: [CGPoint]) -> [CGPoint] {
    source.map { CGPoint(x: CGFloat(canvasWidth) - $0.x, y: $0.y) }
}

private func paired(_ values: [(CGFloat, CGFloat)]) -> [MusclePart] {
    let anatomicalLeft = points(values) // Front view: viewer-right is the person's left.
    return [
        MusclePart(side: "left", points: anatomicalLeft),
        MusclePart(side: "right", points: mirrored(anatomicalLeft))
    ]
}

private let groups: [MuscleGroup] = [
    MuscleGroup(slug: "neck", title: "Шея", parts: [MusclePart(side: nil, points: points([
        (466, 184), (487, 195), (512, 180), (537, 195), (558, 184), (568, 225),
        (552, 266), (530, 286), (512, 274), (494, 286), (472, 266), (456, 225)
    ]))]),
    MuscleGroup(slug: "shoulders", title: "Плечи", parts: paired([
        (604, 265), (639, 250), (678, 260), (702, 287), (710, 326), (704, 366),
        (686, 398), (661, 416), (639, 398), (635, 361), (640, 324), (623, 293)
    ])),
    MuscleGroup(slug: "chest", title: "Грудь", parts: paired([
        (514, 276), (559, 269), (602, 275), (632, 292), (645, 322), (644, 365),
        (635, 401), (613, 425), (580, 440), (546, 431), (522, 414), (513, 384)
    ])),
    MuscleGroup(slug: "biceps", title: "Бицепсы", parts: paired([
        (644, 350), (665, 346), (690, 365), (704, 404), (699, 455), (684, 501),
        (657, 523), (636, 500), (631, 455), (635, 404)
    ])),
    MuscleGroup(slug: "triceps", title: "Трицепсы", parts: paired([
        (683, 347), (706, 361), (720, 397), (717, 443), (704, 485), (689, 512),
        (676, 488), (692, 447), (698, 402), (674, 373)
    ])),
    MuscleGroup(slug: "forearms", title: "Предплечья", parts: paired([
        (687, 507), (716, 513), (738, 541), (758, 577), (778, 618), (790, 660),
        (779, 688), (754, 676), (733, 640), (709, 598), (688, 557), (674, 527)
    ])),
    MuscleGroup(slug: "abs", title: "Пресс", parts: [MusclePart(side: nil, points: points([
        (460, 420), (486, 415), (512, 426), (538, 415), (564, 420), (579, 460),
        (580, 530), (575, 607), (558, 675), (536, 717), (512, 731), (488, 717),
        (466, 675), (449, 607), (444, 530), (445, 460)
    ]))]),
    MuscleGroup(slug: "obliques", title: "Косые мышцы живота", parts: paired([
        (576, 430), (611, 428), (638, 454), (650, 494), (646, 545), (626, 596),
        (601, 642), (572, 675), (554, 642), (569, 591), (577, 536), (568, 484)
    ])),
    MuscleGroup(slug: "serratus", title: "Передние зубчатые", parts: paired([
        (596, 421), (630, 419), (648, 445), (645, 478), (628, 501), (605, 488),
        (584, 458)
    ])),
    MuscleGroup(slug: "hip-flexors", title: "Сгибатели бедра", parts: paired([
        (512, 650), (554, 638), (600, 631), (635, 651), (652, 688), (633, 724),
        (602, 754), (557, 765), (526, 738), (512, 708)
    ])),
    MuscleGroup(slug: "quadriceps", title: "Квадрицепсы", parts: paired([
        (570, 728), (618, 710), (650, 735), (667, 788), (671, 858), (661, 931),
        (637, 991), (608, 1020), (577, 1009), (555, 963), (544, 897), (543, 817)
    ])),
    MuscleGroup(slug: "adductors", title: "Приводящие мышцы", parts: paired([
        (512, 724), (552, 726), (580, 758), (586, 815), (578, 884), (563, 945),
        (543, 996), (520, 1018), (512, 962)
    ])),
    MuscleGroup(slug: "calves", title: "Икры", parts: paired([
        (562, 1012), (602, 1011), (626, 1043), (637, 1094), (633, 1156), (618, 1210),
        (596, 1263), (577, 1300), (555, 1283), (543, 1236), (539, 1173), (543, 1102)
    ])),
    MuscleGroup(slug: "shins", title: "Передняя поверхность голени", parts: paired([
        (519, 1018), (550, 1018), (568, 1061), (570, 1122), (562, 1186), (549, 1260),
        (536, 1310), (518, 1291), (512, 1224), (513, 1130)
    ]))
]

private func smoothClosedPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard points.count > 2 else { return path }
    let count = points.count
    func point(_ index: Int) -> CGPoint { points[(index + count) % count] }
    path.move(to: points[0])
    for index in 0..<count {
        let p0 = point(index - 1)
        let p1 = point(index)
        let p2 = point(index + 1)
        let p3 = point(index + 2)
        path.addCurve(
            to: p2,
            control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
            control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        )
    }
    path.closeSubpath()
    return path
}

private let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)

private func makeContext() -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: canvasWidth,
        height: canvasHeight,
        bitsPerComponent: 8,
        bytesPerRow: canvasWidth * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { fatalError("Cannot create bitmap context") }
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)
    return context
}

private func makeMask(parts: [MusclePart]) -> CGImage {
    let context = makeContext()
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    for part in parts {
        let bitmapPoints = part.points.map { CGPoint(x: $0.x, y: CGFloat(canvasHeight) - $0.y) }
        context.addPath(smoothClosedPath(bitmapPoints))
        context.fillPath()
    }
    guard let image = context.makeImage() else { fatalError("Cannot create mask") }
    return image
}

private func renderedRGBA(_ image: CGImage) -> (context: CGContext, bytes: UnsafeMutablePointer<UInt8>) {
    let context = makeContext()
    context.draw(image, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    guard let data = context.data else { fatalError("Cannot access bitmap data") }
    return (context, data.bindMemory(to: UInt8.self, capacity: canvasWidth * canvasHeight * 4))
}

private func makeHighlight(source: CGImage, mask: CGImage) -> CGImage {
    let sourceBitmap = renderedRGBA(source)
    let maskBitmap = renderedRGBA(mask)
    let output = makeContext()
    guard let outputData = output.data else { fatalError("Cannot access output bitmap") }
    let out = outputData.bindMemory(to: UInt8.self, capacity: canvasWidth * canvasHeight * 4)
    let pixelCount = canvasWidth * canvasHeight

    for pixel in 0..<pixelCount {
        let offset = pixel * 4
        let maskAlpha = Double(maskBitmap.bytes[offset + 3]) / 255
        if maskAlpha <= 0 {
            out[offset] = 0
            out[offset + 1] = 0
            out[offset + 2] = 0
            out[offset + 3] = 0
            continue
        }

        let red = Double(sourceBitmap.bytes[offset])
        let green = Double(sourceBitmap.bytes[offset + 1])
        let blue = Double(sourceBitmap.bytes[offset + 2])
        let luminance = min(max((red * 0.2126 + green * 0.7152 + blue * 0.0722) / 255, 0), 1)
        let alpha = maskAlpha * (0.46 + luminance * 0.50)
        let targetRed = 0.92 + luminance * 0.08
        let targetGreen = 0.12 + luminance * 0.44
        let targetBlue = 0.16 + luminance * 0.34

        out[offset] = UInt8(min(255, targetRed * alpha * 255))
        out[offset + 1] = UInt8(min(255, targetGreen * alpha * 255))
        out[offset + 2] = UInt8(min(255, targetBlue * alpha * 255))
        out[offset + 3] = UInt8(min(255, alpha * 255))
    }

    guard let sharp = output.makeImage() else { fatalError("Cannot create highlight") }
    return sharp
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "MuscleOverlay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create PNG destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "MuscleOverlay", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot write PNG"])
    }
}

private func writeRegionJSON(to url: URL) throws {
    let payload: [[String: Any]] = groups.map { group in
        [
            "id": group.slug,
            "title": group.title,
            "parts": group.parts.map { part in
                [
                    "side": part.side.map { $0 as Any } ?? NSNull(),
                    "points": part.points.map { point in
                        ["x": point.x / CGFloat(canvasWidth), "y": point.y / CGFloat(canvasHeight)]
                    }
                ]
            }
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: [
        "canvas": ["width": canvasWidth, "height": canvasHeight],
        "coordinateSystem": "normalized-top-left",
        "frontViewSideConvention": "anatomical-left-is-viewer-right",
        "groups": payload
    ], options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

private func safeCreateDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

private func assetSuffix(_ filename: String) -> String {
    filename.split(separator: "-").map { part in
        part.prefix(1).uppercased() + part.dropFirst()
    }.joined()
}

private func installImageSet(
    named name: String,
    source: URL,
    in catalog: URL,
    template: Bool
) throws {
    let imageSet = catalog.appendingPathComponent("\(name).imageset", isDirectory: true)
    try safeCreateDirectory(imageSet)
    let destination = imageSet.appendingPathComponent("source.png")
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: source, to: destination)
    var contents: [String: Any] = [
        "images": [["filename": "source.png", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1]
    ]
    if template {
        contents["properties"] = ["template-rendering-intent": "template"]
    }
    try writeJSON(contents, to: imageSet.appendingPathComponent("Contents.json"))
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift generate_muscle_overlays.swift <source.png> <output-directory>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let source = NSImage(contentsOf: sourceURL),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
      sourceCG.width == canvasWidth,
      sourceCG.height == canvasHeight else {
    fatalError("The source image must be 1024 × 1536 px")
}

let masksURL = outputURL.appendingPathComponent("masks", isDirectory: true)
let highlightsURL = outputURL.appendingPathComponent("highlights", isDirectory: true)
let baseURL = outputURL.appendingPathComponent("base", isDirectory: true)
try safeCreateDirectory(masksURL)
try safeCreateDirectory(highlightsURL)
try safeCreateDirectory(baseURL)
let baseImageURL = baseURL.appendingPathComponent("female-anatomy-front.png")
if !FileManager.default.fileExists(atPath: baseImageURL.path) {
    try FileManager.default.copyItem(at: sourceURL, to: baseImageURL)
}

var combinedHighlights: [CGImage] = []
var generatedNames: [String] = []
for group in groups {
    let variants: [(String, [MusclePart])] = [(group.slug, group.parts)] + group.parts.compactMap { part in
        part.side.map { ("\(group.slug)-\($0)", [part]) }
    }

    for (name, parts) in variants {
        let mask = makeMask(parts: parts)
        let highlight = makeHighlight(source: sourceCG, mask: mask)
        try writePNG(mask, to: masksURL.appendingPathComponent("\(name).png"))
        try writePNG(highlight, to: highlightsURL.appendingPathComponent("\(name).png"))
        generatedNames.append(name)
        if name == group.slug { combinedHighlights.append(highlight) }
    }
}

let previewContext = makeContext()
previewContext.draw(sourceCG, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
for highlight in combinedHighlights {
    previewContext.draw(highlight, in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
}
if let preview = previewContext.makeImage() {
    try writePNG(preview, to: outputURL.appendingPathComponent("all-regions-preview.png"))
}

try writeRegionJSON(to: outputURL.appendingPathComponent("regions.json"))

let catalogURL = outputURL.appendingPathComponent("MuscleOverlays.xcassets", isDirectory: true)
try safeCreateDirectory(catalogURL)
try writeJSON(["info": ["author": "xcode", "version": 1]], to: catalogURL.appendingPathComponent("Contents.json"))
try installImageSet(named: "FemaleAnatomyFront", source: baseImageURL, in: catalogURL, template: false)
for name in generatedNames {
    let suffix = assetSuffix(name)
    try installImageSet(
        named: "MuscleMask\(suffix)",
        source: masksURL.appendingPathComponent("\(name).png"),
        in: catalogURL,
        template: true
    )
    try installImageSet(
        named: "MuscleHighlight\(suffix)",
        source: highlightsURL.appendingPathComponent("\(name).png"),
        in: catalogURL,
        template: false
    )
}
print("Created \(groups.count) aligned muscle groups in \(outputURL.path)")
