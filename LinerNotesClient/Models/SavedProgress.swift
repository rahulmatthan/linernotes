import Foundation

struct SavedProgress: Codable {
    let huntId: UUID
    let huntVersion: String
    let currentLinkIndex: Int
    let solvedLinks: [Int]
    let startTime: Date?
    let savedAt: Date

    private static let userDefaultsKey = "savedGameProgress"

    /// Save progress to UserDefaults
    static func save(from gameState: GameState) {
        let progress = SavedProgress(
            huntId: gameState.treasureHunt.id,
            huntVersion: gameState.treasureHunt.version,
            currentLinkIndex: gameState.currentLinkIndex,
            solvedLinks: Array(gameState.solvedLinks),
            startTime: gameState.startTime,
            savedAt: Date()
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(progress)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 Progress saved: link \(progress.currentLinkIndex + 1), \(progress.solvedLinks.count) solved")
        } catch {
            print("⚠️ Failed to save progress: \(error)")
        }
    }

    /// Load saved progress from UserDefaults
    static func load() -> SavedProgress? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let progress = try decoder.decode(SavedProgress.self, from: data)
            print("📖 Loaded saved progress: link \(progress.currentLinkIndex + 1), \(progress.solvedLinks.count) solved")
            return progress
        } catch {
            print("⚠️ Failed to load progress: \(error)")
            return nil
        }
    }

    /// Clear saved progress from UserDefaults
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🗑️ Progress cleared")
    }

    /// Check if saved progress matches the given hunt (same ID and version)
    func matches(hunt: TreasureHunt) -> Bool {
        return huntId == hunt.id && huntVersion == hunt.version
    }
}
