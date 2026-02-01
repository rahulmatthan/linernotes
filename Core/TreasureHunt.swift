import Foundation

struct TreasureHunt: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var createdDate: Date
    var modifiedDate: Date
    var links: [ChainLink]
    var version: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        links: [ChainLink]? = nil,
        version: String = "2.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.version = version

        if let links = links {
            self.links = links
        } else {
            // Start with 1 empty link - table editor allows adding more
            self.links = [ChainLink.empty]
        }
    }

    var isComplete: Bool {
        !links.isEmpty && links.allSatisfy { $0.isValid }
    }

    var completionPercentage: Double {
        guard !links.isEmpty else { return 0 }
        let validCount = links.filter { $0.isValid }.count
        return Double(validCount) / Double(links.count) * 100.0
    }
}

extension TreasureHunt {
    static var empty: TreasureHunt {
        TreasureHunt(
            name: "New Treasure Hunt",
            description: ""
        )
    }
}
