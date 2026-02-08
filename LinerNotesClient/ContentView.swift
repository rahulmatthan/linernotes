import SwiftUI

struct ContentView: View {
    // State for navigation flow
    @State private var showingHuntSelection = false
    @State private var selectedHunt: TreasureHunt?
    @State private var savedProgress: SavedProgress?
    @State private var selectedHuntFileId: String?

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
                    showingHuntSelection = true
                } label: {
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
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .fullScreenCover(isPresented: $showingHuntSelection) {
                HuntSelectionView(
                    onHuntSelected: { hunt, progress, huntFileId in
                        selectedHunt = hunt
                        savedProgress = progress
                        selectedHuntFileId = huntFileId
                        showingHuntSelection = false
                    },
                    onClose: {
                        showingHuntSelection = false
                    }
                )
            }
            .fullScreenCover(item: $selectedHunt) { hunt in
                GameView(
                    treasureHunt: hunt,
                    savedProgress: savedProgress,
                    huntFileId: selectedHuntFileId ?? hunt.name
                )
                .onDisappear {
                    // Reset state when game is dismissed
                    selectedHunt = nil
                    savedProgress = nil
                    selectedHuntFileId = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
