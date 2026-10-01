import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let width = 1024
private let height = 1536

private struct Region { let points: [CGPoint] }

private func region(_ values: [(CGFloat, CGFloat)]) -> Region {
    Region(points: values.map(CGPoint.init))
}

private func mirrored(_ source: Region) -> Region {
    Region(points: source.points.map { CGPoint(x: CGFloat(width) - $0.x, y: $0.y) })
}

private func paired(_ regions: [Region]) -> [Region] {
    regions + regions.map(mirrored)
}

private func symmetric(_ rightHalf: [(CGFloat, CGFloat)]) -> Region {
    let right = rightHalf.map(CGPoint.init)
    let left = right.dropFirst().dropLast().reversed().map { CGPoint(x: CGFloat(width) - $0.x, y: $0.y) }
    return Region(points: right + left)
}

private let femaleRegions: [Region] = [
    symmetric([
        (512,5),(554,12),(578,40),(585,82),(581,128),(565,167),(550,188),
        (562,214),(590,238),(624,250),(662,252),(691,269),(707,296),(713,329),
        (709,360),(699,385),(681,405),(657,417),(646,440),(642,470),(646,505),
        (650,544),(647,580),(636,613),(618,646),(632,668),(650,690),(663,716),
        (669,742),(665,765),(650,783),(629,790),(608,783),(589,770),(566,756),
        (542,744),(512,734)
    ])
    ] + paired([
        region([
            (644,344),(672,336),(697,345),(713,367),(720,398),(718,430),(711,461),
            (701,491),(686,518),(700,522),(719,533),(737,552),(753,577),(768,603),
            (783,629),(795,653),(799,674),(792,689),(781,695),(790,704),(810,699),
            (831,704),(850,716),(865,733),(863,750),(850,757),(835,753),(847,770),
            (845,786),(833,794),(817,787),(824,805),(818,820),(805,825),(793,815),
            (789,800),(780,783),(773,763),(768,738),(759,711),(747,688),(733,665),
            (719,641),(706,617),(692,592),(681,566),(670,541),(659,517),(648,486),
            (640,452),(637,416)
        ]),
        region([
            (520,709),(554,706),(590,713),(620,730),(647,757),(665,792),(673,836),
            (673,881),(666,927),(653,969),(635,1001),(615,1019),(628,1041),(638,1072),
            (642,1110),(640,1152),(633,1190),(622,1221),(610,1253),(599,1287),
            (590,1318),(596,1344),(612,1362),(630,1373),(643,1387),(644,1404),
            (632,1419),(610,1428),(587,1425),(568,1415),(555,1402),(549,1385),
            (550,1364),(545,1337),(537,1304),(528,1268),(520,1227),(515,1181),
            (513,1132),(515,1083),(522,1043),(536,1006),(545,967),(548,924),
            (547,876),(542,827),(535,780)
        ])
    ])

private let maleRegions: [Region] = [
    symmetric([
        (512,5),(556,12),(580,40),(587,82),(583,128),(568,166),(554,188),
        (570,211),(603,235),(642,248),(683,249),(714,265),(733,290),(742,321),
        (741,352),(733,382),(717,405),(694,421),(672,430),(661,451),(660,483),
        (666,520),(670,556),(665,592),(653,625),(635,654),(646,675),(660,697),
        (671,722),(676,747),(672,770),(658,789),(638,799),(616,793),(596,781),
        (575,766),(551,751),(529,740),(512,734)
    ])
    ] + paired([
        region([
            (656,339),(687,332),(714,341),(733,363),(744,393),(747,426),(743,459),
            (735,490),(720,520),(705,544),(721,550),(741,566),(759,588),(776,613),
            (793,640),(806,666),(810,686),(803,701),(792,707),(802,716),(823,711),
            (845,717),(864,729),(879,745),(877,762),(864,769),(849,765),(861,782),
            (859,799),(847,807),(831,800),(838,818),(831,833),(818,838),(805,828),
            (800,812),(790,794),(782,773),(776,748),(767,721),(755,698),(741,675),
            (727,651),(713,626),(699,601),(688,574),(677,549),(666,523),(655,491),
            (648,456),(647,417),(650,377)
        ]),
        region([
            (520,708),(555,705),(591,711),(623,728),(650,754),(668,789),(676,832),
            (676,877),(670,923),(657,966),(639,999),(619,1018),(632,1040),(642,1072),
            (646,1111),(644,1153),(637,1191),(626,1223),(614,1255),(603,1289),
            (594,1320),(600,1346),(616,1364),(634,1375),(647,1389),(648,1406),
            (636,1421),(614,1430),(591,1427),(572,1417),(559,1404),(553,1387),
            (554,1366),(549,1339),(541,1306),(532,1270),(524,1229),(519,1183),
            (517,1134),(519,1085),(526,1045),(540,1008),(549,969),(552,926),
            (551,878),(546,829),(539,781)
        ])
    ])

private let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)

private func context() -> CGContext {
    guard let value = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo.rawValue
    ) else { fatalError("Cannot create context") }
    value.setShouldAntialias(true)
    value.setAllowsAntialiasing(true)
    return value
}

private func smoothPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard points.count > 2 else { return path }
    func point(_ index: Int) -> CGPoint { points[(index + points.count) % points.count] }
    path.move(to: points[0])
    for index in 0..<points.count {
        let p0 = point(index - 1), p1 = point(index), p2 = point(index + 1), p3 = point(index + 2)
        path.addCurve(
            to: p2,
            control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
            control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        )
    }
    path.closeSubpath()
    return path
}

private func rendered(_ image: CGImage) -> (context: CGContext, bytes: UnsafeMutablePointer<UInt8>) {
    let value = context()
    value.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (value, value.data!.bindMemory(to: UInt8.self, capacity: width * height * 4))
}

private func makeMask(_ regions: [Region]) -> CGImage {
    let value = context()
    value.setFillColor(CGColor(gray: 1, alpha: 1))
    for item in regions {
        let points = item.points.map { CGPoint(x: $0.x, y: CGFloat(height) - $0.y) }
        value.addPath(smoothPath(points))
        value.fillPath()
    }
    return value.makeImage()!
}

private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

private func clean(source: CGImage, regions: [Region]) -> CGImage {
    let sourceBitmap = rendered(source)
    let maskBitmap = rendered(makeMask(regions))
    let output = context()
    let out = output.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)

    for pixel in 0..<(width * height) {
        let offset = pixel * 4
        let maskAlpha = Double(maskBitmap.bytes[offset + 3]) / 255
        let maximum = Double(max(sourceBitmap.bytes[offset], max(sourceBitmap.bytes[offset + 1], sourceBitmap.bytes[offset + 2]))) / 255
        let gate = clamp((maximum - 0.36) / 0.16)
        let alpha = maskAlpha * gate
        out[offset] = UInt8(Double(sourceBitmap.bytes[offset]) * alpha)
        out[offset + 1] = UInt8(Double(sourceBitmap.bytes[offset + 1]) * alpha)
        out[offset + 2] = UInt8(Double(sourceBitmap.bytes[offset + 2]) * alpha)
        out[offset + 3] = UInt8(alpha * 255)
    }
    return output.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write output") }
}

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: swift remove_front_avatar_glow.swift <source.png> <output.png> <female|male>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let profile = CommandLine.arguments[3]
guard let image = NSImage(contentsOf: sourceURL),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      cgImage.width == width,
      cgImage.height == height else { fatalError("Source must be 1024 x 1536") }

writePNG(clean(source: cgImage, regions: profile == "male" ? maleRegions : femaleRegions), to: outputURL)
