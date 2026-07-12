import Foundation

struct SavedProgress: Codable {
    let huntId: UUID
    let huntVersion: String
    let currentLinkIndex: Int
    let solvedLinks: [Int]
    let startTime: Date?
    let savedAt: Date
    let isComplete: Bool
    let totalLinks: Int  // Store total for progress calculation
    let inLoopbackPhase: Bool
    let loopbackSolved: Bool

    enum CodingKeys: String, CodingKey {
        case huntId, huntVersion, currentLinkIndex, solvedLinks, startTime, savedAt
        case isComplete, totalLinks, inLoopbackPhase, loopbackSolved
    }

    init(
        huntId: UUID,
        huntVersion: String,
        currentLinkIndex: Int,
        solvedLinks: [Int],
        startTime: Date?,
        savedAt: Date,
        isComplete: Bool,
        totalLinks: Int,
        inLoopbackPhase: Bool,
        loopbackSolved: Bool
    ) {
        self.huntId = huntId
        self.huntVersion = huntVersion
        self.currentLinkIndex = currentLinkIndex
        self.solvedLinks = solvedLinks
        self.startTime = startTime
        self.savedAt = savedAt
        self.isComplete = isComplete
        self.totalLinks = totalLinks
        self.inLoopbackPhase = inLoopbackPhase
        self.loopbackSolved = loopbackSolved
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        huntId = try container.decode(UUID.self, forKey: .huntId)
        huntVersion = try container.decode(String.self, forKey: .huntVersion)
        currentLinkIndex = try container.decode(Int.self, forKey: .currentLinkIndex)
        solvedLinks = try container.decode([Int].self, forKey: .solvedLinks)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        totalLinks = try container.decode(Int.self, forKey: .totalLinks)
        inLoopbackPhase = try container.decodeIfPresent(Bool.self, forKey: .inLoopbackPhase) ?? false
        loopbackSolved = try container.decodeIfPresent(Bool.self, forKey: .loopbackSolved) ?? false
    }

    // Legacy key for migration
    private static let legacyUserDefaultsKey = "savedGameProgress"

    // Per-hunt storage key prefix
    private static let keyPrefix = "savedProgress_"

    /// Generate per-hunt storage key
    private static func key(for huntFileId: String) -> String {
        "\(keyPrefix)\(huntFileId)"
    }

    /// Save progress to UserDefaults for a specific hunt
    static func save(
        from gameState: GameState,
        huntFileId: String
    ) {
        let progress = SavedProgress(
            huntId: gameState.treasureHunt.id,
            huntVersion: gameState.treasureHunt.version,
            currentLinkIndex: gameState.currentLinkIndex,
            solvedLinks: Array(gameState.solvedLinks),
            startTime: gameState.startTime,
            savedAt: Date(),
            isComplete: gameState.isComplete,
            totalLinks: gameState.treasureHunt.links.count,
            inLoopbackPhase: false,
            loopbackSolved: false
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(progress)
            UserDefaults.standard.set(data, forKey: key(for: huntFileId))
            print("💾 Progress saved for hunt '\(huntFileId)': link \(progress.currentLinkIndex + 1), \(progress.solvedLinks.count) solved")
        } catch {
            print("⚠️ Failed to save progress: \(error)")
        }
    }

    /// Load saved progress from UserDefaults for a specific hunt
    static func load(for huntFileId: String) -> SavedProgress? {
        guard let data = UserDefaults.standard.data(forKey: key(for: huntFileId)) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let progress = try decoder.decode(SavedProgress.self, from: data)
            print("📖 Loaded saved progress for hunt '\(huntFileId)': link \(progress.currentLinkIndex + 1), \(progress.solvedLinks.count) solved")
            return progress
        } catch {
            print("⚠️ Failed to load progress: \(error)")
            return nil
        }
    }

    /// Clear saved progress from UserDefaults for a specific hunt
    static func clear(for huntFileId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: huntFileId))
        print("🗑️ Progress cleared for hunt '\(huntFileId)'")
    }

    /// Get all saved progress entries (for hunt selection display)
    static func allProgress() -> [String: SavedProgress] {
        var results: [String: SavedProgress] = [:]

        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(keyPrefix) else { continue }

            let huntFileId = String(key.dropFirst(keyPrefix.count))
            guard let data = defaults.data(forKey: key),
                  let progress = try? decoder.decode(SavedProgress.self, from: data) else {
                continue
            }

            results[huntFileId] = progress
        }

        return results
    }

    /// Get hunt status for display
    func getStatus() -> HuntStatus {
        if isComplete {
            return .completed
        } else if solvedLinks.isEmpty && currentLinkIndex == 0 {
            return .notStarted
        } else {
            let progress = totalLinks > 0 ? Double(solvedLinks.count) / Double(totalLinks) : 0
            return .inProgress(progress: progress)
        }
    }

    /// Check if saved progress matches the given hunt (same ID and version)
    func matches(hunt: TreasureHunt) -> Bool {
        return huntId == hunt.id && huntVersion == hunt.version
    }

    // MARK: - Legacy Migration

    /// Load legacy saved progress (single-hunt format)
    static func loadLegacy() -> SavedProgress? {
        guard let data = UserDefaults.standard.data(forKey: legacyUserDefaultsKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try to decode with new format first
            if let progress = try? decoder.decode(SavedProgress.self, from: data) {
                return progress
            }

            // Fall back to legacy format without isComplete and totalLinks
            let legacyProgress = try decoder.decode(LegacySavedProgress.self, from: data)
            return SavedProgress(
                huntId: legacyProgress.huntId,
                huntVersion: legacyProgress.huntVersion,
                currentLinkIndex: legacyProgress.currentLinkIndex,
                solvedLinks: legacyProgress.solvedLinks,
                startTime: legacyProgress.startTime,
                savedAt: legacyProgress.savedAt,
                isComplete: false,
                totalLinks: 0,
                inLoopbackPhase: false,
                loopbackSolved: false
            )
        } catch {
            print("⚠️ Failed to load legacy progress: \(error)")
            return nil
        }
    }

    /// Clear legacy saved progress
    static func clearLegacy() {
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        print("🗑️ Legacy progress cleared")
    }
}

/// Legacy format for migration
private struct LegacySavedProgress: Codable {
    let huntId: UUID
    let huntVersion: String
    let currentLinkIndex: Int
    let solvedLinks: [Int]
    let startTime: Date?
    let savedAt: Date
}
