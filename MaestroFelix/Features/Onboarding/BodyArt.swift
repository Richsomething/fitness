import SwiftUI

/// A painted figure for the body map: a raster body placed in the 200 × 500 design space, its muscle
/// overlays, and for every zone the parts of those overlays that light when it is marked. An overlay
/// holds both sides of the body, so a paired zone takes the half on its side; a joint takes a soft
/// band of the muscles around it. Artwork lives in Assets › Anatomy, made by tools/make_anatomy_assets.py,
/// which also prints the frames and hotspots below.
struct BodyArt {
    struct Muscle {
        let image: String
        /// Where the cropped overlay sits, in design units.
        let frame: CGRect
    }

    struct Layer {
        let zone: BodyZone
        /// `.left` or `.right` for one of a pair; nil for a zone on the midline.
        let side: BodySide?
        let muscle: Muscle
        /// The part of the overlay that belongs to the zone, in design units.
        let window: CGRect
        /// A band cut out of a longer muscle fades out at its top and bottom.
        let isBand: Bool
    }

    let image: String
    let frame: CGRect
    let muscles: [Muscle]
    let layers: [Layer]
}

// MARK: - Paintings

extension BodyArt {
    static let femaleFront = front("female-front", frame: CGRect(x: -24.19, y: 3.61, width: 248.39, height: 496.78), muscles: [
        ("neck-trapezius", CGRect(x: 79.88, y: 65.36, width: 40.24, height: 37.47)),
        ("shoulders", CGRect(x: 30.96, y: 88.95, width: 138.07, height: 58.97)),
        ("chest", CGRect(x: 52.47, y: 95.89, width: 95.05, height: 60.36)),
        ("biceps", CGRect(x: 33.05, y: 120.87, width: 133.91, height: 61.75)),
        ("triceps", CGRect(x: 26.8, y: 121.56, width: 146.4, height: 58.28)),
        ("forearms", CGRect(x: 0.09, y: 173.95, width: 199.82, height: 67.99)),
        ("abs", CGRect(x: 79.19, y: 146.89, width: 41.63, height: 109.62)),
        ("serratus", CGRect(x: 53.51, y: 145.85, width: 92.97, height: 42.32)),
        ("lats", CGRect(x: 47.27, y: 141.68, width: 105.46, height: 70.08)),
        ("obliques", CGRect(x: 54.9, y: 168.74, width: 90.2, height: 69.38)),
        ("hip-flexors", CGRect(x: 60.11, y: 223.55, width: 79.79, height: 40.94)),
        ("hips", CGRect(x: 43.11, y: 222.86, width: 113.79, height: 52.73)),
        ("adductors", CGRect(x: 75.37, y: 245.06, width: 49.26, height: 111.71)),
        ("quadriceps", CGRect(x: 42.07, y: 246.45, width: 115.87, height: 108.24)),
        ("calves", CGRect(x: 54.55, y: 349.13, width: 90.89, height: 109.28)),
        ("shins", CGRect(x: 77.1, y: 352.6, width: 45.79, height: 107.89)),
    ])

    static let maleFront = front("male-front", frame: CGRect(x: -26.44, y: 3.61, width: 252.89, height: 496.77), muscles: [
        ("neck-trapezius", CGRect(x: 72.63, y: 62.16, width: 54.73, height: 39.49)),
        ("shoulders", CGRect(x: 23.79, y: 87.1, width: 152.43, height: 58.89)),
        ("chest", CGRect(x: 48.04, y: 92.3, width: 103.93, height: 60.28)),
        ("biceps", CGRect(x: 20.32, y: 118.97, width: 159.35, height: 73.79)),
        ("triceps", CGRect(x: 17.9, y: 118.97, width: 164.2, height: 69.63)),
        ("forearms", CGRect(x: -12.93, y: 174.05, width: 225.87, height: 69.63)),
        ("abs", CGRect(x: 77.14, y: 145.3, width: 45.73, height: 113.97)),
        ("serratus", CGRect(x: 50.12, y: 142.88, width: 99.77, height: 46.07)),
        ("lats", CGRect(x: 40.76, y: 140.45, width: 118.48, height: 73.44)),
        ("obliques", CGRect(x: 51.15, y: 167.13, width: 97.69, height: 71.71)),
        ("hip-flexors", CGRect(x: 58.08, y: 222.9, width: 83.83, height: 42.96)),
        ("hips", CGRect(x: 43.53, y: 222.55, width: 112.93, height: 52.66)),
        ("adductors", CGRect(x: 76.1, y: 245.07, width: 47.81, height: 112.24)),
        ("quadriceps", CGRect(x: 41.8, y: 246.8, width: 116.4, height: 108.08)),
        ("calves", CGRect(x: 53.58, y: 348.65, width: 92.84, height: 109.82)),
        ("shins", CGRect(x: 76.79, y: 351.77, width: 46.42, height: 108.78)),
    ])

    static let femaleBack = back("female-back", frame: CGRect(x: -27.61, y: 3.63, width: 255.21, height: 496.74), muscles: [
        ("neck", CGRect(x: 79.47, y: 35.79, width: 41.05, height: 54.39)),
        ("trapezius", CGRect(x: 51.42, y: 54.26, width: 97.16, height: 122.47)),
        ("rear-shoulders", CGRect(x: 33.63, y: 86.76, width: 132.74, height: 49.95)),
        ("infraspinatus", CGRect(x: 40.82, y: 98.39, width: 118.37, height: 37.63)),
        ("teres-major", CGRect(x: 39.45, y: 120.63, width: 121.11, height: 30.79)),
        ("triceps", CGRect(x: 25.42, y: 122.68, width: 149.16, height: 64.66)),
        ("forearms", CGRect(x: -7.76, y: 174.34, width: 215.18, height: 64.66)),
        ("lats", CGRect(x: 47.32, y: 132.26, width: 105.37, height: 92.03)),
        ("erector-spinae", CGRect(x: 79.13, y: 122.68, width: 41.74, height: 121.11)),
        ("gluteus-medius", CGRect(x: 48.34, y: 196.24, width: 103.66, height: 48.92)),
        ("gluteus-maximus", CGRect(x: 47.32, y: 198.63, width: 105.37, height: 63.29)),
        ("hamstrings", CGRect(x: 46.29, y: 255.08, width: 107.42, height: 98.53)),
        ("adductors", CGRect(x: 82.89, y: 250.97, width: 34.21, height: 91.68)),
        ("calves", CGRect(x: 55.87, y: 341.63, width: 88.26, height: 79.37)),
        ("soleus", CGRect(x: 56.21, y: 364.21, width: 87.58, height: 79.03)),
        ("achilles-tendons", CGRect(x: 71.26, y: 411.08, width: 57.47, height: 70.13)),
    ])

    static let maleBack = back("male-back", frame: CGRect(x: -36.33, y: 3.63, width: 272.66, height: 496.74), muscles: [
        ("neck", CGRect(x: 75.88, y: 33.39, width: 48.24, height: 59.53)),
        ("trapezius", CGRect(x: 46.12, y: 52.89, width: 108.11, height: 126.92)),
        ("rear-shoulders", CGRect(x: 23.54, y: 84.37, width: 152.58, height: 61.92)),
        ("infraspinatus", CGRect(x: 33.8, y: 97.03, width: 132.74, height: 41.05)),
        ("teres-major", CGRect(x: 34.49, y: 119.26, width: 131.37, height: 34.55)),
        ("triceps", CGRect(x: 17.04, y: 121.66, width: 166.26, height: 69.11)),
        ("forearms", CGRect(x: -17.17, y: 175.37, width: 234.68, height: 67.39)),
        ("lats", CGRect(x: 41.33, y: 131.58, width: 117.68, height: 97.16)),
        ("erector-spinae", CGRect(x: 77.25, y: 120.97, width: 45.84, height: 127.26)),
        ("gluteus-medius", CGRect(x: 47.14, y: 197.61, width: 105.37, height: 50.97)),
        ("gluteus-maximus", CGRect(x: 46.12, y: 200.34, width: 107.76, height: 66.71)),
        ("hamstrings", CGRect(x: 44.07, y: 258.5, width: 111.18, height: 100.92)),
        ("adductors", CGRect(x: 81.7, y: 254.74, width: 36.95, height: 88.26)),
        ("calves", CGRect(x: 52.96, y: 346.42, width: 94.42, height: 81.76)),
        ("soleus", CGRect(x: 53.99, y: 369.68, width: 92.37, height: 80.39)),
        ("achilles-tendons", CGRect(x: 69.38, y: 417.58, width: 61.58, height: 69.79)),
    ])

    /// Muscles by overlay name; a missing one draws nothing.
    private struct Chart {
        let prefix: String
        let frames: [String: CGRect]

        subscript(_ name: String) -> Muscle {
            Muscle(image: "\(prefix)-\(name)", frame: frames[name] ?? .zero)
        }
    }

    private static func front(_ image: String, frame: CGRect, muscles: [(String, CGRect)]) -> BodyArt {
        let m = Chart(prefix: image, frames: Dictionary(uniqueKeysWithValues: muscles))
        let layers = midline(.neck, [m["neck-trapezius"]])
            + paired(.shoulders, [m["shoulders"]], facing: .front)
            + paired(.elbows, [m["biceps"], m["triceps"], m["forearms"]], band: 150...200, facing: .front)
            + paired(.wrists, [m["forearms"]], band: 200...256, facing: .front)
            + midline(.hips, [m["hips"], m["hip-flexors"]])
            + midline(.hips, [m["adductors"], m["quadriceps"]], band: 236...296)
            + paired(.knees, [m["quadriceps"], m["calves"], m["shins"]], band: 314...380, facing: .front)
            + paired(.ankles, [m["calves"], m["shins"]], band: 418...476, facing: .front)
        return BodyArt(image: image, frame: frame, muscles: muscles.map { m[$0.0] }, layers: layers)
    }

    private static func back(_ image: String, frame: CGRect, muscles: [(String, CGRect)]) -> BodyArt {
        let m = Chart(prefix: image, frames: Dictionary(uniqueKeysWithValues: muscles))
        let layers = midline(.neck, [m["neck"]])
            + midline(.upperBack, [m["infraspinatus"], m["teres-major"]])
            + midline(.upperBack, [m["trapezius"]], band: 50...160)
            + midline(.lowerBack, [m["erector-spinae"]], band: 168...252)
            + midline(.lowerBack, [m["lats"]], band: 188...236)
            + paired(.shoulders, [m["rear-shoulders"]], facing: .back)
            + paired(.elbows, [m["triceps"], m["forearms"]], band: 152...206, facing: .back)
            + paired(.wrists, [m["forearms"]], band: 200...256, facing: .back)
            + midline(.hips, [m["gluteus-medius"], m["gluteus-maximus"]])
            + midline(.hips, [m["hamstrings"], m["adductors"]], band: 244...298)
            + paired(.knees, [m["hamstrings"], m["calves"]], band: 318...378, facing: .back)
            + paired(.ankles, [m["soleus"], m["achilles-tendons"]], band: 420...490, facing: .back)
        return BodyArt(image: image, frame: frame, muscles: muscles.map { m[$0.0] }, layers: layers)
    }

    private static let everywhere: ClosedRange<CGFloat> = -100...700

    private static func midline(_ zone: BodyZone, _ muscles: [Muscle], band: ClosedRange<CGFloat>? = nil) -> [Layer] {
        let rows = band ?? everywhere
        return muscles.map { muscle in
            Layer(zone: zone, side: nil, muscle: muscle,
                  window: CGRect(x: -100, y: rows.lowerBound, width: 400, height: rows.upperBound - rows.lowerBound),
                  isBand: band != nil)
        }
    }

    /// Each half of the overlay belongs to one side. From the front the person's left is on the
    /// viewer's right; from behind it is on the viewer's left.
    private static func paired(_ zone: BodyZone, _ muscles: [Muscle], band: ClosedRange<CGFloat>? = nil,
                               facing: BodyFigure.Facing) -> [Layer] {
        let rows = band ?? everywhere
        let height = rows.upperBound - rows.lowerBound
        let viewerLeft: BodySide = facing == .front ? .right : .left
        let viewerRight: BodySide = facing == .front ? .left : .right
        return muscles.flatMap { muscle in
            [Layer(zone: zone, side: viewerLeft, muscle: muscle,
                   window: CGRect(x: -100, y: rows.lowerBound, width: 200, height: height), isBand: band != nil),
             Layer(zone: zone, side: viewerRight, muscle: muscle,
                   window: CGRect(x: 100, y: rows.lowerBound, width: 200, height: height), isBand: band != nil)]
        }
    }
}

// MARK: - Figures

extension BodyFigure {
    enum Build {
        case male, female

        init(_ gender: ProfileGender?) {
            self = gender == .female ? .female : .male
        }
    }

    static func anatomy(facing: Facing, build: Build = .male) -> BodyFigure {
        switch (build, facing) {
        case (.male, .front): maleFront
        case (.male, .back): maleBack
        case (.female, .front): femaleFront
        case (.female, .back): femaleBack
        }
    }

    private typealias ZonePlace = (zone: BodyZone, region: CGRect, hotspot: CGPoint)

    // Hotspots come from the asset script; paired places are on the viewer's left and mirrored.
    private static let femaleFront = painted(BodyArt.femaleFront, facing: .front, midline: [
        (.neck, CGRect(x: 82, y: 62, width: 36, height: 40), CGPoint(x: 100, y: 84)),
        (.hips, CGRect(x: 54, y: 214, width: 92, height: 64), CGPoint(x: 100, y: 240)),
    ], paired: [
        (.shoulders, CGRect(x: 28, y: 88, width: 38, height: 50), CGPoint(x: 45, y: 115)),
        (.elbows, CGRect(x: 16, y: 158, width: 38, height: 44), CGPoint(x: 35, y: 180)),
        (.wrists, CGRect(x: -26, y: 212, width: 52, height: 80), CGPoint(x: 7, y: 235)),
        (.knees, CGRect(x: 56, y: 320, width: 38, height: 52), CGPoint(x: 74, y: 346)),
        (.ankles, CGRect(x: 62, y: 440, width: 36, height: 62), CGPoint(x: 84, y: 460)),
    ])

    private static let maleFront = painted(BodyArt.maleFront, facing: .front, midline: [
        (.neck, CGRect(x: 80, y: 60, width: 40, height: 42), CGPoint(x: 100, y: 82)),
        (.hips, CGRect(x: 54, y: 214, width: 92, height: 64), CGPoint(x: 100, y: 240)),
    ], paired: [
        (.shoulders, CGRect(x: 20, y: 86, width: 40, height: 52), CGPoint(x: 40, y: 113)),
        (.elbows, CGRect(x: 6, y: 158, width: 38, height: 44), CGPoint(x: 25, y: 180)),
        (.wrists, CGRect(x: -38, y: 212, width: 54, height: 80), CGPoint(x: -4, y: 237)),
        (.knees, CGRect(x: 56, y: 320, width: 38, height: 52), CGPoint(x: 74, y: 346)),
        (.ankles, CGRect(x: 62, y: 440, width: 36, height: 62), CGPoint(x: 84, y: 460)),
    ])

    private static let femaleBack = painted(BodyArt.femaleBack, facing: .back, midline: [
        (.neck, CGRect(x: 82, y: 46, width: 36, height: 40), CGPoint(x: 100, y: 68)),
        (.upperBack, CGRect(x: 62, y: 90, width: 76, height: 72), CGPoint(x: 100, y: 118)),
        (.lowerBack, CGRect(x: 70, y: 166, width: 60, height: 50), CGPoint(x: 100, y: 200)),
        (.hips, CGRect(x: 52, y: 218, width: 96, height: 62), CGPoint(x: 100, y: 236)),
    ], paired: [
        (.shoulders, CGRect(x: 28, y: 88, width: 38, height: 44), CGPoint(x: 49, y: 109)),
        (.elbows, CGRect(x: 10, y: 158, width: 38, height: 44), CGPoint(x: 29, y: 180)),
        (.wrists, CGRect(x: -34, y: 212, width: 52, height: 80), CGPoint(x: 0, y: 233)),
        (.knees, CGRect(x: 60, y: 322, width: 38, height: 52), CGPoint(x: 81, y: 347)),
        (.ankles, CGRect(x: 62, y: 446, width: 36, height: 56), CGPoint(x: 82, y: 468)),
    ])

    private static let maleBack = painted(BodyArt.maleBack, facing: .back, midline: [
        (.neck, CGRect(x: 80, y: 46, width: 40, height: 42), CGPoint(x: 100, y: 69)),
        (.upperBack, CGRect(x: 58, y: 90, width: 84, height: 72), CGPoint(x: 100, y: 118)),
        (.lowerBack, CGRect(x: 68, y: 166, width: 64, height: 52), CGPoint(x: 100, y: 202)),
        (.hips, CGRect(x: 50, y: 220, width: 100, height: 62), CGPoint(x: 100, y: 238)),
    ], paired: [
        (.shoulders, CGRect(x: 20, y: 86, width: 42, height: 50), CGPoint(x: 44, y: 112)),
        (.elbows, CGRect(x: 2, y: 158, width: 40, height: 46), CGPoint(x: 21, y: 181)),
        (.wrists, CGRect(x: -44, y: 212, width: 54, height: 80), CGPoint(x: -9, y: 236)),
        (.knees, CGRect(x: 56, y: 326, width: 40, height: 52), CGPoint(x: 76, y: 352)),
        (.ankles, CGRect(x: 60, y: 450, width: 38, height: 52), CGPoint(x: 80, y: 474)),
    ])

    private static func painted(_ art: BodyArt, facing: Facing, midline: [ZonePlace], paired: [ZonePlace]) -> BodyFigure {
        let viewerLeft: BodySide = facing == .front ? .right : .left
        let viewerRight: BodySide = facing == .front ? .left : .right
        var regions = midline.map { place in
            Region(zone: place.zone, side: nil, path: Path(roundedRect: place.region, cornerRadius: 14), center: place.hotspot)
        }
        var hotspots = midline.map { Hotspot(zone: $0.zone, side: nil, point: $0.hotspot) }
        for place in paired {
            let rect = place.region
            let mirrored = CGRect(x: size.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
            regions.append(Region(zone: place.zone, side: viewerLeft, path: Path(roundedRect: rect, cornerRadius: 14),
                                  center: place.hotspot))
            regions.append(Region(zone: place.zone, side: viewerRight, path: Path(roundedRect: mirrored, cornerRadius: 14),
                                  center: mirror(place.hotspot)))
            hotspots.append(Hotspot(zone: place.zone, side: viewerLeft, point: place.hotspot))
            hotspots.append(Hotspot(zone: place.zone, side: viewerRight, point: mirror(place.hotspot)))
        }
        return BodyFigure(facing: facing, art: art, regions: regions, hotspots: hotspots)
    }
}
