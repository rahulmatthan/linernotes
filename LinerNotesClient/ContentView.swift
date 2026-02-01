import SwiftUI

struct ContentView: View {
    // MARK: - Configuration
    // Remote hunt JSON hosted on GitHub
    private let remoteHuntURL = "https://raw.githubusercontent.com/rahulmatthan/linernotes-data/refs/heads/main/Version%201.json"

    @State private var selectedHunt: TreasureHunt?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                    Text("LinerNotes")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    Text("Musical Treasure Hunt")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    Task {
                        await loadHunt()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.8, green: 0.67, blue: 0.0))
                            )
                    } else {
                        Label("Start", systemImage: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.84, blue: 0.0),
                                                Color(red: 0.9, green: 0.75, blue: 0.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                }
                .disabled(isLoading)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .fullScreenCover(item: $selectedHunt) { hunt in
                GameView(treasureHunt: hunt)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Hunt Loading (Priority: Remote → Cached → Bundled → Demo)

    private func loadHunt() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Try remote fetch first
        if let hunt = await fetchRemoteHunt() {
            print("🟢 Loaded hunt from remote: \(hunt.name) with \(hunt.links.count) links")
            selectedHunt = hunt
            return
        }

        // 2. Fall back to cached version
        if let hunt = loadCachedHunt() {
            print("🟡 Loaded cached hunt: \(hunt.name) with \(hunt.links.count) links")
            selectedHunt = hunt
            return
        }

        // 3. Fall back to bundled version
        if let hunt = loadBundledHunt() {
            print("🟠 Loaded bundled hunt: \(hunt.name) with \(hunt.links.count) links")
            selectedHunt = hunt
            return
        }

        // 4. Last resort: demo hunt
        print("🔴 Using fallback demo hunt")
        selectedHunt = createDemoHunt()
    }

    private func fetchRemoteHunt() async -> TreasureHunt? {
        guard let url = URL(string: remoteHuntURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ Remote fetch failed: bad status code")
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let hunt = try decoder.decode(TreasureHunt.self, from: data)

            // Cache the successful fetch
            cacheHunt(data: data)

            return hunt
        } catch {
            print("⚠️ Remote fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func cacheHunt(data: Data) {
        guard let cacheURL = getCacheURL() else { return }
        do {
            try data.write(to: cacheURL)
            print("💾 Hunt cached successfully")
        } catch {
            print("⚠️ Failed to cache hunt: \(error)")
        }
    }

    private func loadCachedHunt() -> TreasureHunt? {
        guard let cacheURL = getCacheURL(),
              FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TreasureHunt.self, from: data)
        } catch {
            print("⚠️ Failed to load cached hunt: \(error)")
            return nil
        }
    }

    private func loadBundledHunt() -> TreasureHunt? {
        guard let url = Bundle.main.url(forResource: "LinerNotesHunt", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TreasureHunt.self, from: data)
        } catch {
            print("⚠️ Failed to load bundled hunt: \(error)")
            return nil
        }
    }

    private func getCacheURL() -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDir.appendingPathComponent("LinerNotesHunt.json")
    }

    private func createDemoHunt() -> TreasureHunt {
        let demoLinks = [
            ChainLink(
                clue: "This Canadian artist's 2020 hit about nighttime driving became one of the biggest songs of the decade with its retro 80s synth sound.",
                hint1: "He can't feel his face when he's with you",
                hint2: "The song title refers to bright lights that blind",
                multipleChoiceOptions: ["The Weeknd", "Drake", "Justin Bieber", "Post Malone"],
                correctAnswers: ["The Weeknd", "the weeknd", "Weeknd", "weeknd"],
                isrc: "USUG12000523",
                songInfoText: "Blinding Lights spent 90 weeks in the Billboard Hot 100 top 10."
            ),
            ChainLink(
                clue: "This British singer-songwriter's 2017 hit about attraction became the most-streamed song of that year.",
                hint1: "He's thinking out loud about your body",
                hint2: "The song is about the shape of someone",
                multipleChoiceOptions: ["Ed Sheeran", "Sam Smith", "Harry Styles", "Zayn"],
                correctAnswers: ["Ed Sheeran", "ed sheeran", "Sheeran", "sheeran"],
                isrc: "GBAHS1600463",
                songInfoText: "Shape of You was the first song to reach 3 billion streams on Spotify."
            ),
            ChainLink(
                clue: "This 2014 collaboration features a Hawaiian singer telling you not to believe him when he says he's too hot.",
                hint1: "Saturday night and we're in the spot",
                hint2: "The funk is definitely uptown",
                multipleChoiceOptions: ["Bruno Mars", "Pharrell Williams", "Justin Timberlake", "Usher"],
                correctAnswers: ["Bruno Mars", "bruno mars", "Mark Ronson", "mark ronson"],
                isrc: "GBARL1401524",
                songInfoText: "Uptown Funk spent 14 weeks at #1 on the Billboard Hot 100."
            )
        ]

        let hunt = TreasureHunt(
            name: "2010s Hits Demo",
            description: "A journey through the decade's biggest songs",
            links: demoLinks
        )

        return hunt
    }
}

#Preview {
    ContentView()
}
