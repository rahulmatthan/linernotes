import Foundation
import AppKit

extension FileManager {
    /// The directory where treasure hunt JSON files are stored (also a git repo for GitHub sync)
    static var treasureHuntDirectory: URL {
        // Use the linernotes-data git repo in Coding folder
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let treasureHuntURL = homeURL.appendingPathComponent("Coding/linernotes-data", isDirectory: true)

        if !FileManager.default.fileExists(atPath: treasureHuntURL.path) {
            try? FileManager.default.createDirectory(at: treasureHuntURL, withIntermediateDirectories: true)
        }

        return treasureHuntURL
    }

    /// URL for the manifest.json file
    static var manifestURL: URL {
        treasureHuntDirectory.appendingPathComponent("manifest.json")
    }

    /// URL for the admin-only manifest (includes unpublished draft entries)
    static var adminManifestURL: URL {
        treasureHuntDirectory.appendingPathComponent("manifest.admin.json")
    }

    // MARK: - Manifest Operations

    /// Load the manifest from disk
    static func loadManifest() throws -> HuntManifest {
        // Prefer admin manifest if present; it preserves published/unpublished state.
        let adminURL = adminManifestURL
        if FileManager.default.fileExists(atPath: adminURL.path) {
            let data = try Data(contentsOf: adminURL)
            let decoder = JSONDecoder()
            return try decoder.decode(HuntManifest.self, from: data)
        }

        // Fallback to published manifest for first-run migration.
        let url = manifestURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            // Return empty manifest if file doesn't exist
            return .empty
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(HuntManifest.self, from: data)
    }

    /// Save the manifest to disk
    static func saveManifest(_ manifest: HuntManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Save full admin manifest (all entries).
        let adminData = try encoder.encode(manifest)
        try adminData.write(to: adminManifestURL)

        // Export client-facing manifest (published entries only).
        let publishedData = try encoder.encode(manifest.publishedOnly)
        try publishedData.write(to: manifestURL)
    }

    /// Get the expected filename for a hunt based on its manifest entry ID
    static func huntFileURL(for entryId: String) -> URL {
        treasureHuntDirectory.appendingPathComponent("\(entryId).json")
    }

    /// Push changes to GitHub using git
    static func pushToGitHub() async throws -> String {
        let repoPath = treasureHuntDirectory.path

        // Run git commands
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", """
            cd "\(repoPath)" && \
            git add -A && \
            git commit -m "Update treasure hunt content" && \
            git push 2>&1 || echo "Already up to date"
            """]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !output.contains("Already up to date") && !output.contains("nothing to commit") {
            throw NSError(domain: "GitError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }

        return output
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
