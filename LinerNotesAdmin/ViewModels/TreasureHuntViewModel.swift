import Foundation
import SwiftUI

@MainActor
class TreasureHuntViewModel: ObservableObject {
    @Published var currentHunt: TreasureHunt
    @Published var selectedLinkIndex: Int = 0
    @Published var hasUnsavedChanges: Bool = false
    @Published var showingPreview: Bool = false
    @Published var showingMusicSearch: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    @Published var isPushing: Bool = false
    @Published var pushSuccessMessage: String?
    @Published var showingPushSuccess: Bool = false

    // Manifest management
    @Published var manifest: HuntManifest = .empty
    @Published var currentManifestEntry: HuntManifestEntry = .empty
    @Published var showingManifestEditor: Bool = false
    @Published var showingManifestManager: Bool = false

    // Pending action after manifest is saved
    private var pendingAction: PendingAction?

    enum PendingAction {
        case save
        case push
    }

    init(hunt: TreasureHunt = .empty) {
        self.currentHunt = hunt
        loadManifest()
    }

    // MARK: - Manifest Management

    private func loadManifest() {
        do {
            manifest = try FileManager.loadManifest()
            print("📋 Loaded manifest with \(manifest.hunts.count) entries")
        } catch {
            print("⚠️ Failed to load manifest: \(error)")
            manifest = .empty
        }
    }

    /// Check if the current hunt has a valid manifest entry
    var hasValidManifestEntry: Bool {
        currentManifestEntry.isValid && currentManifestEntry.id == currentHunt.name
    }

    /// Prepare manifest entry from current hunt
    func prepareManifestEntry() {
        // Try to find existing entry for this hunt
        if let existing = manifest.entry(for: currentHunt.name) {
            currentManifestEntry = existing
            // Update song count in case it changed
            currentManifestEntry.songCount = currentHunt.links.count
        } else {
            // Create new entry from hunt
            currentManifestEntry = HuntManifestEntry.from(hunt: currentHunt)
        }
    }

    /// Save the manifest entry and update manifest file
    func saveManifestEntry() {
        // Update song count
        currentManifestEntry.songCount = currentHunt.links.count

        // Upsert into manifest
        manifest.upsert(currentManifestEntry)

        // Save manifest to disk
        do {
            try FileManager.saveManifest(manifest)
            print("📋 Saved manifest with \(manifest.hunts.count) entries")
        } catch {
            errorMessage = "Failed to save manifest: \(error.localizedDescription)"
            showingError = true
        }
    }

    /// Called when manifest editor completes
    func onManifestEditorSave() {
        saveManifestEntry()

        // Execute pending action
        if let action = pendingAction {
            pendingAction = nil
            Task {
                switch action {
                case .save:
                    await performSave()
                case .push:
                    await performPush()
                }
            }
        }
    }

    func onManifestEditorCancel() {
        pendingAction = nil
    }

    // MARK: - Link Management

    func updateLink(at index: Int, with link: ChainLink) {
        guard index >= 0 && index < currentHunt.links.count else { return }
        currentHunt.links[index] = link
        currentHunt.modifiedDate = Date()
        hasUnsavedChanges = true
    }

    func updateHuntMetadata(name: String, description: String) {
        currentHunt.name = name
        currentHunt.description = description
        currentHunt.modifiedDate = Date()
        hasUnsavedChanges = true
    }

    // MARK: - Save Workflow

    func saveToFile() async {
        prepareManifestEntry()

        if !currentManifestEntry.isValid {
            // Show manifest editor first
            pendingAction = .save
            showingManifestEditor = true
        } else {
            await performSave()
        }
    }

    /// Save a local draft of the current hunt without requiring a valid manifest entry.
    /// This is useful while authoring content before the hunt is ready to publish.
    func saveDraft() async {
        let filename = currentHunt.name
        let url = FileManager.huntFileURL(for: filename)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(currentHunt)
            try data.write(to: url)

            hasUnsavedChanges = false
            print("💾 Saved draft treasure hunt to: \(url.path)")
        } catch {
            errorMessage = "Failed to save draft: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func performSave() async {
        // Save manifest entry first
        saveManifestEntry()

        // Determine filename from manifest entry ID
        let filename = currentManifestEntry.id
        let url = FileManager.huntFileURL(for: filename)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(currentHunt)
            try data.write(to: url)

            hasUnsavedChanges = false
            print("✅ Saved treasure hunt to: \(url.path)")
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Load

    func loadFromFile() async {
        do {
            if let hunt = try await FileManager.loadTreasureHunt() {
                currentHunt = hunt
                selectedLinkIndex = 0
                hasUnsavedChanges = false

                // Try to load existing manifest entry
                loadManifest()
                if let entry = manifest.entry(for: hunt.name) {
                    currentManifestEntry = entry
                } else {
                    currentManifestEntry = HuntManifestEntry.from(hunt: hunt)
                }
            }
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            showingError = true
        }
    }

    func newHunt() {
        currentHunt = TreasureHunt(
            name: "New Treasure Hunt",
            description: "",
            links: [ChainLink.empty]  // Start with one empty row
        )
        selectedLinkIndex = 0
        hasUnsavedChanges = false
        currentManifestEntry = .empty
    }

    func addNewLink() {
        currentHunt.links.append(ChainLink.empty)
        currentHunt.modifiedDate = Date()
        hasUnsavedChanges = true
    }

    func deleteLink(at index: Int) {
        guard index >= 0 && index < currentHunt.links.count else { return }
        // Keep at least one row
        if currentHunt.links.count > 1 {
            currentHunt.links.remove(at: index)
            currentHunt.modifiedDate = Date()
            hasUnsavedChanges = true

            // Adjust selected index if needed
            if selectedLinkIndex >= currentHunt.links.count {
                selectedLinkIndex = currentHunt.links.count - 1
            }
        }
    }

    var currentLink: ChainLink {
        guard selectedLinkIndex >= 0 && selectedLinkIndex < currentHunt.links.count else {
            return ChainLink.empty
        }
        return currentHunt.links[selectedLinkIndex]
    }

    // MARK: - Push Workflow

    func pushToGitHub() async {
        prepareManifestEntry()

        if !currentManifestEntry.isValid {
            // Show manifest editor first
            pendingAction = .push
            showingManifestEditor = true
        } else {
            await performPush()
        }
    }

    private func performPush() async {
        isPushing = true
        defer { isPushing = false }

        // Publishing the actively edited hunt should make it visible in the client.
        currentManifestEntry.isPublished = true

        // Save manifest entry and hunt file first
        saveManifestEntry()

        // Save the hunt file with the correct filename
        let filename = currentManifestEntry.id
        let url = FileManager.huntFileURL(for: filename)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(currentHunt)
            try data.write(to: url)
            hasUnsavedChanges = false
        } catch {
            errorMessage = "Failed to save before push: \(error.localizedDescription)"
            showingError = true
            return
        }

        // Now push to GitHub
        do {
            let output = try await FileManager.pushToGitHub()
            if output.contains("nothing to commit") || output.contains("Already up to date") {
                pushSuccessMessage = "Already up to date - no changes to push"
            } else {
                pushSuccessMessage = "Successfully pushed to GitHub!"
            }
            showingPushSuccess = true
        } catch {
            errorMessage = "Failed to push: \(error.localizedDescription)"
            showingError = true
        }
    }
}
