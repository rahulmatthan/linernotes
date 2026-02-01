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

    init(hunt: TreasureHunt = .empty) {
        self.currentHunt = hunt
    }

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

    func saveToFile() async {
        do {
            if let url = try await FileManager.saveTreasureHunt(currentHunt) {
                hasUnsavedChanges = false
                print("Saved treasure hunt to: \(url.path)")
            }
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
    }

    func loadFromFile() async {
        do {
            if let hunt = try await FileManager.loadTreasureHunt() {
                currentHunt = hunt
                selectedLinkIndex = 0
                hasUnsavedChanges = false
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
}
