import AppKit

enum PetError: LocalizedError {
    case asset(String)
    var errorDescription: String? {
        switch self { case .asset(let name): return "캐릭터 이미지를 읽지 못했습니다: \(name)" }
    }
}

struct Sprite {
    let image: CGImage
    // Bounds in atlas coordinates, with the origin at the top left.
    let silhouette: CGRect
    init(_ image: CGImage) throws {
        self.image = image
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let context = CGContext(data: &pixels, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PetError.asset("pixels") }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var left = image.width, top = image.height, right = 0, bottom = 0
        for y in 0..<image.height {
            for x in 0..<image.width where pixels[(y * image.width + x) * 4 + 3] > 32 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top else { throw PetError.asset("empty sprite") }
        silhouette = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
    }
}

final class Sprites {
    private(set) var sheets: [String: [Sprite]] = [:]

    init(directory: URL) throws {
        func load(_ name: String) throws -> CGImage {
            let url = directory.appendingPathComponent(name + ".png")
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw PetError.asset(url.path) }
            return image
        }
        func crop(_ image: CGImage, _ rect: CGRect) throws -> Sprite {
            guard let cropped = image.cropping(to: rect) else { throw PetError.asset("crop \(rect)") }
            return try Sprite(cropped)
        }
        func grid(_ name: String, _ columns: Int = 2, _ rows: Int = 2) throws -> [Sprite] {
            let image = try load(name)
            return try (0..<(columns * rows)).map { index in
                let col = index % columns, row = index / columns
                let x = col * image.width / columns, y = row * image.height / rows
                return try crop(image, CGRect(x: x, y: y, width: (col + 1) * image.width / columns - x,
                                              height: (row + 1) * image.height / rows - y))
            }
        }
        for (key, name) in [("base", "doongi"), ("blink", "doongi-blink"), ("look", "doongi-look"),
                            ("playful", "doongi-playful"), ("walkPose", "doongi-walk"), ("back", "doongi-back")] {
            sheets[key] = try grid(name)
        }
        sheets["rest"] = try grid("doongi-rest", 3, 2)
        sheets["walk"] = try grid("doongi-walk-cycle", 4, 2)
        sheets["glance"] = try grid("kikki-walk-glance", 4, 2)
        let drop = try load("doongi-phone-drop")
        let split = Int(Double(drop.width) * 0.5263), half = drop.height / 2
        sheets["drop"] = try [CGRect(x: 0, y: 0, width: split, height: half),
                              CGRect(x: drop.width / 2, y: 0, width: drop.width / 2, height: half),
                              CGRect(x: 0, y: half, width: split, height: half),
                              CGRect(x: split, y: half, width: drop.width - split, height: half)].map { try crop(drop, $0) }
        let pickup = try load("doongi-pickup")
        sheets["pickup"] = try (0..<4).map { i in
            var x = (i % 2) * pickup.width / 2
            var width = pickup.width / 2
            if i == 0 { width += 13 }
            if i == 1 { x += 13; width -= 13 }
            return try crop(pickup, CGRect(x: x, y: (i / 2) * pickup.height / 2, width: width, height: pickup.height / 2))
        }
        let lift = try load("kikki-lift-cycle"), cuts = [0,462,887,1318,1774]
        sheets["lift"] = try (0..<8).map { i in
            let x = cuts[i % 4] * lift.width / 1774, end = cuts[i % 4 + 1] * lift.width / 1774
            let y = (i / 4) * lift.height / 2
            return try crop(lift, CGRect(x: x, y: y, width: end - x, height: (i / 4 + 1) * lift.height / 2 - y))
        }
        let landed = try load("doongi-lift")
        sheets["landed"] = [try crop(landed, CGRect(x: landed.width / 2, y: landed.height / 2 + 18,
                                                   width: landed.width / 2, height: landed.height / 2 - 18))]
        let posture = try load("kikki-posture-transitions")
        let rowCuts = [0,436,770,1086], columnCuts = [[0,344,693,1062,1448],[0,368,729,1092,1448],[0,378,724,1086,1448]]
        sheets["transition"] = try (0..<12).map { i in
            let row = i / 4, col = i % 4
            return try crop(posture, CGRect(x: columnCuts[row][col], y: rowCuts[row],
                                            width: columnCuts[row][col+1] - columnCuts[row][col], height: rowCuts[row+1] - rowCuts[row]))
        }
        let reference = self["base", 0].silhouette
        for key in ["rest", "pickup", "back", "landed"] {
            sheets[key] = try sheets[key]!.enumerated().map { i, sprite in
                let mode = key == "rest" ? [2,2,1,1,0,0][i] : (key == "pickup" ? 1 : 0)
                let target = self["base", mode].silhouette
                let factor = target.width / sprite.silhouette.width
                return try aligned(sprite, factor: factor, center: target.midX, anchor: target.maxY, top: false)
            }
        }
        for key in ["walk", "glance", "walkPose"] {
            sheets[key] = try sheets[key]!.enumerated().map { i, sprite in
                let height = key == "walkPose" ? [510.0,470,470,425][i] : 470
                return try aligned(sprite, factor: height / sprite.silhouette.height, center: 290, anchor: 590, top: false)
            }
        }
        for key in ["lift", "transition"] {
            let frames = sheets[key]!
            let maxWidth = frames.map { $0.silhouette.width }.max()!
            let maxHeight = frames.map { $0.silhouette.height }.max()!
            let availableHeight = key == "lift" ? 627 - 28 - reference.minY : reference.height
            let factor = min(reference.width / maxWidth, availableHeight / maxHeight)
            sheets[key] = try frames.map {
                try aligned($0, factor: factor, center: reference.midX,
                            anchor: key == "lift" ? reference.minY : reference.maxY, top: key == "lift")
            }
        }
    }

    subscript(_ name: String, _ index: Int) -> Sprite { sheets[name]![index] }

    private func aligned(_ sprite: Sprite, factor: Double, center: Double, anchor: Double, top: Bool) throws -> Sprite {
        guard let context = CGContext(data: nil, width: 627, height: 627, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PetError.asset("alignment") }
        let x = center - sprite.silhouette.midX * factor
        let y = anchor - (top ? sprite.silhouette.minY : sprite.silhouette.maxY) * factor
        // Convert top-left atlas coordinates to Core Graphics' bottom-left drawing space.
        context.draw(sprite.image, in: CGRect(x: x, y: 627 - y - Double(sprite.image.height) * factor,
                                              width: Double(sprite.image.width) * factor, height: Double(sprite.image.height) * factor))
        guard let result = context.makeImage() else { throw PetError.asset("alignment output") }
        return try Sprite(result)
    }
}
