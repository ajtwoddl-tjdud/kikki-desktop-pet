import Foundation

enum MischiefLevel: String, CaseIterable {
    case normal, mild, off
    var title: String { self == .normal ? "기본" : self == .mild ? "순한맛" : "끄기" }
    var chance: Int { self == .normal ? 60 : self == .mild ? 20 : 0 }
    var cooldown: Double { self == .mild ? 120 : 30 }
    var acknowledgement: String {
        self == .normal ? "알겠어. 쪼끔 킹받게 해볼게." : self == .mild ? "응. 가끔만 장난칠게." : "알았어. 순하게 옆에 있을게."
    }
}

struct MischiefCatalog: Decodable {
    let version: Int
    let contexts: [String: [String]]
    init(url: URL) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard version == 1, contexts.values.allSatisfy({ !$0.isEmpty && $0.allSatisfy { !$0.isEmpty } }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}

struct MischiefLine {
    let text: String
    let isMeme: Bool
}

final class MischiefDialogue {
    let catalog: MischiefCatalog
    var level = MischiefLevel.normal {
        didSet { nextAllowedAt = 0 }
    }
    private(set) var nextAllowedAt = 0.0
    private var previousLine: String?

    init(catalog: MischiefCatalog) { self.catalog = catalog }

    func pick(context: String, fallback: String, time: Double, roll: Int, selection: Int) -> MischiefLine {
        guard roll < level.chance, time >= nextAllowedAt,
              let choices = catalog.contexts[context], !choices.isEmpty else {
            return MischiefLine(text: fallback, isMeme: false)
        }
        let fresh = choices.filter { $0 != previousLine }
        let available = fresh.isEmpty ? choices : fresh
        let text = available[selection % available.count]
        previousLine = text
        nextAllowedAt = time + level.cooldown
        return MischiefLine(text: text, isMeme: true)
    }
}
