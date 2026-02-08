import Foundation

/// Manifest containing the list of available treasure hunts
struct HuntManifest: Codable {
    let hunts: [HuntInfo]
}

/// Metadata about a treasure hunt for display in the selection screen
struct HuntInfo: Codable, Identifiable {
    let id: String           // Unique identifier (matches JSON filename without extension)
    let name: String         // Display name
    let description: String  // Short description for selection screen
    let difficulty: String?  // Optional difficulty level
    let songCount: Int       // Number of clues

    /// Constructs the remote URL for fetching this hunt's JSON
    func remoteURL(baseURL: String) -> URL? {
        // URL-encode the id for spaces and special characters
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return URL(string: "\(baseURL)\(encodedId).json")
    }
}

/// Status of a hunt for display purposes
enum HuntStatus: Equatable {
    case notStarted
    case inProgress(progress: Double)  // 0.0 to 1.0
    case completed
}
