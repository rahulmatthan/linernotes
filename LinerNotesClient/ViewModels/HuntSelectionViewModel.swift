import Foundation

@available(iOS 15.0, *)
@MainActor
class HuntSelectionViewModel: ObservableObject {
    @Published var huntInfos: [HuntInfo] = []
    @Published var huntStatuses: [String: HuntStatus] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Base URLs for remote content
    private let baseURL = "https://raw.githubusercontent.com/rahulmatthan/linernotes-data/refs/heads/main/"
    private let manifestURL = "https://raw.githubusercontent.com/rahulmatthan/linernotes-data/refs/heads/main/manifest.json"

    init() {
        loadCachedStatuses()
    }

    /// Load hunt statuses from saved progress
    private func loadCachedStatuses() {
        let allProgress = SavedProgress.allProgress()
        for (huntId, progress) in allProgress {
            huntStatuses[huntId] = progress.getStatus()
        }
    }

    /// Load the manifest of available hunts
    func loadManifest() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Try remote fetch first
        if let manifest = await fetchRemoteManifest() {
            huntInfos = manifest.hunts
            cacheManifest(manifest)
            print("🟢 Loaded \(manifest.hunts.count) hunts from remote manifest")
        } else if let manifest = loadCachedManifest() {
            // Fall back to cached manifest
            huntInfos = manifest.hunts
            print("🟡 Loaded \(manifest.hunts.count) hunts from cached manifest")
        } else {
            // Fall back to default single hunt
            huntInfos = [createDefaultHuntInfo()]
            print("🟠 Using default hunt info")
        }

        // Update statuses for all hunts
        refreshStatuses()
    }

    /// Fetch manifest from remote URL
    private func fetchRemoteManifest() async -> HuntManifest? {
        guard let url = URL(string: manifestURL) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ Manifest fetch failed: bad status code")
                return nil
            }

            let decoder = JSONDecoder()
            return try decoder.decode(HuntManifest.self, from: data)
        } catch {
            print("⚠️ Manifest fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Cache manifest locally
    private func cacheManifest(_ manifest: HuntManifest) {
        guard let cacheURL = getManifestCacheURL() else { return }
        do {
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: cacheURL)
            print("💾 Manifest cached successfully")
        } catch {
            print("⚠️ Failed to cache manifest: \(error)")
        }
    }

    /// Load cached manifest
    private func loadCachedManifest() -> HuntManifest? {
        guard let cacheURL = getManifestCacheURL(),
              FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode(HuntManifest.self, from: data)
        } catch {
            print("⚠️ Failed to load cached manifest: \(error)")
            return nil
        }
    }

    private func getManifestCacheURL() -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDir.appendingPathComponent("LinerNotesManifest.json")
    }

    /// Create default hunt info for fallback
    private func createDefaultHuntInfo() -> HuntInfo {
        HuntInfo(
            id: "Version 1",
            name: "Classic Hits",
            description: "A journey through iconic songs",
            difficulty: nil,
            songCount: 20
        )
    }

    /// Refresh hunt statuses from saved progress
    func refreshStatuses() {
        let allProgress = SavedProgress.allProgress()

        for huntInfo in huntInfos {
            if let progress = allProgress[huntInfo.id] {
                huntStatuses[huntInfo.id] = progress.getStatus()
            } else {
                huntStatuses[huntInfo.id] = .notStarted
            }
        }
    }

    /// Get status for a specific hunt
    func getStatus(for huntId: String) -> HuntStatus {
        huntStatuses[huntId] ?? .notStarted
    }

    /// Load a specific hunt by its info
    func loadHunt(info: HuntInfo) async -> TreasureHunt? {
        // Try remote fetch first
        if let hunt = await fetchRemoteHunt(info: info) {
            return hunt
        }

        // Try cached version
        if let hunt = loadCachedHunt(huntId: info.id) {
            return hunt
        }

        return nil
    }

    /// Fetch hunt from remote URL
    private func fetchRemoteHunt(info: HuntInfo) async -> TreasureHunt? {
        guard let url = info.remoteURL(baseURL: baseURL) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ Hunt fetch failed for '\(info.id)': bad status code")
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let hunt = try decoder.decode(TreasureHunt.self, from: data)

            // Cache the successful fetch
            cacheHunt(data: data, huntId: info.id)
            print("🟢 Loaded hunt '\(info.id)' from remote: \(hunt.links.count) links")

            return hunt
        } catch {
            print("⚠️ Hunt fetch failed for '\(info.id)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Cache a hunt locally
    private func cacheHunt(data: Data, huntId: String) {
        guard let cacheURL = getCacheURL(for: huntId) else { return }
        do {
            try data.write(to: cacheURL)
            print("💾 Hunt '\(huntId)' cached successfully")
        } catch {
            print("⚠️ Failed to cache hunt '\(huntId)': \(error)")
        }
    }

    /// Load cached hunt
    private func loadCachedHunt(huntId: String) -> TreasureHunt? {
        guard let cacheURL = getCacheURL(for: huntId),
              FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let hunt = try decoder.decode(TreasureHunt.self, from: data)
            print("🟡 Loaded hunt '\(huntId)' from cache: \(hunt.links.count) links")
            return hunt
        } catch {
            print("⚠️ Failed to load cached hunt '\(huntId)': \(error)")
            return nil
        }
    }

    private func getCacheURL(for huntId: String) -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        // Sanitize huntId for use in filename
        let safeId = huntId.replacingOccurrences(of: "/", with: "_")
                          .replacingOccurrences(of: " ", with: "_")
        return cacheDir.appendingPathComponent("hunt_\(safeId).json")
    }

    /// Get saved progress for a specific hunt
    func getSavedProgress(for huntId: String) -> SavedProgress? {
        SavedProgress.load(for: huntId)
    }

    /// Clear progress for a specific hunt
    func clearProgress(for huntId: String) {
        SavedProgress.clear(for: huntId)
        huntStatuses[huntId] = .notStarted
    }
}
