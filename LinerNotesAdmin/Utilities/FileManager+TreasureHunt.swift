import Foundation
import AppKit

extension FileManager {
    static var treasureHuntDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let treasureHuntURL = documentsURL.appendingPathComponent("LinerNotes/TreasureHunts", isDirectory: true)

        if !FileManager.default.fileExists(atPath: treasureHuntURL.path) {
            try? FileManager.default.createDirectory(at: treasureHuntURL, withIntermediateDirectories: true)
        }

        return treasureHuntURL
    }

    @MainActor
    static func saveTreasureHunt(_ hunt: TreasureHunt) async throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(hunt.name).json"
        panel.directoryURL = treasureHuntDirectory
        panel.message = "Save Treasure Hunt"

        let response = await panel.begin()

        guard response == .OK, let url = panel.url else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(hunt)
        try data.write(to: url)

        return url
    }

    @MainActor
    static func loadTreasureHunt() async throws -> TreasureHunt? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.directoryURL = treasureHuntDirectory
        panel.message = "Load Treasure Hunt"
        panel.allowsMultipleSelection = false

        let response = await panel.begin()

        guard response == .OK, let url = panel.urls.first else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let hunt = try decoder.decode(TreasureHunt.self, from: data)
        return hunt
    }
}
