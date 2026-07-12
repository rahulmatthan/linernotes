import Foundation

/// A single entry in the hunt manifest for the Admin app
struct HuntManifestEntry: Codable, Identifiable, Equatable {
    var id: String           // Unique identifier (matches JSON filename without extension)
    var name: String         // Display name
    var description: String  // Short description for selection screen
    var difficulty: String?  // Optional difficulty level
    var songCount: Int       // Number of clues (auto-calculated from hunt)
    var isPublished: Bool    // Whether this hunt should appear in client manifest

    /// Check if the entry has all required fields filled
    var isValid: Bool {
        !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        songCount > 0
    }

    /// Create an empty entry
    static var empty: HuntManifestEntry {
        HuntManifestEntry(id: "", name: "", description: "", difficulty: nil, songCount: 0, isPublished: false)
    }

    /// Create an entry from a TreasureHunt
    static func from(hunt: TreasureHunt) -> HuntManifestEntry {
        HuntManifestEntry(
            id: hunt.name,  // Default to hunt name as ID
            name: hunt.name,
            description: hunt.description,
            difficulty: nil,
            songCount: hunt.links.count,
            isPublished: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, difficulty, songCount, isPublished
    }

    init(id: String, name: String, description: String, difficulty: String?, songCount: Int, isPublished: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.songCount = songCount
        self.isPublished = isPublished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
        songCount = try container.decode(Int.self, forKey: .songCount)
        // Older manifests won't have this key; treat existing entries as published.
        isPublished = try container.decodeIfPresent(Bool.self, forKey: .isPublished) ?? true
    }
}

/// The full manifest containing all hunt entries
struct HuntManifest: Codable {
    var hunts: [HuntManifestEntry]

    /// Find an entry by ID
    func entry(for id: String) -> HuntManifestEntry? {
        hunts.first { $0.id == id }
    }

    /// Update or add an entry
    mutating func upsert(_ entry: HuntManifestEntry) {
        if let index = hunts.firstIndex(where: { $0.id == entry.id }) {
            hunts[index] = entry
        } else {
            hunts.append(entry)
        }
    }

    /// Remove an entry by ID
    mutating func remove(id: String) {
        hunts.removeAll { $0.id == id }
    }

    /// Empty manifest
    static var empty: HuntManifest {
        HuntManifest(hunts: [])
    }

    var publishedOnly: HuntManifest {
        HuntManifest(hunts: hunts.filter { $0.isPublished })
    }
}
