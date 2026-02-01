import SwiftUI

struct GameView: View {
    let treasureHunt: TreasureHunt
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GameViewModel

    init(treasureHunt: TreasureHunt) {
        self.treasureHunt = treasureHunt
        self._viewModel = StateObject(wrappedValue: GameViewModel(treasureHunt: treasureHunt))
    }

    var body: some View {
        ZStack {
            // Background layers
            GeometryReader { geometry in
                ZStack {
                    // Layer 1: Default gradient (always present as base)
                    defaultGradientBackground

                    // Layer 2: Blurred album art background (fills screen)
                    if let albumArtData = viewModel.currentAlbumArtData,
                       let uiImage = UIImage(data: albumArtData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .blur(radius: 30)
                            .overlay(Color.black.opacity(0.3))
                            .id(albumArtData.hashValue) // Force refresh when art changes
                    } else if viewModel.isSongPlaying, let artworkURL = viewModel.currentArtworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                                    .blur(radius: 30)
                                    .overlay(Color.black.opacity(0.3))
                            }
                        }
                        .id(artworkURL) // Force refresh when URL changes
                    }

                    // Layer 3: Clear letterboxed album art (centered, fits within screen)
                    if let albumArtData = viewModel.currentAlbumArtData,
                       let uiImage = UIImage(data: albumArtData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geometry.size.width - 32, maxHeight: geometry.size.height * 0.5)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 20)
                            .id(albumArtData.hashValue) // Force refresh when art changes
                    } else if viewModel.isSongPlaying, let artworkURL = viewModel.currentArtworkURL {
                        AsyncImage(url: artworkURL) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width - 32, maxHeight: geometry.size.height * 0.5)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.5), radius: 20)
                            }
                        }
                        .id(artworkURL) // Force refresh when URL changes
                    }
                }
                .animation(.easeInOut(duration: 1.5), value: viewModel.currentAlbumArtData)
                .animation(.easeInOut(duration: 1.5), value: viewModel.currentArtworkURL)
            }
            .ignoresSafeArea()

            if viewModel.showingCompletionScreen {
                // End of current playlist message
                VStack(spacing: 32) {
                    Spacer()

                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                    VStack(spacing: 16) {
                        Text("You've reached the end!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("This is currently the last song in LinerNotes. More is on its way.")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Text("Refresh your app to update the playlist.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    Button("Close") {
                        viewModel.endGame()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .cornerRadius(12)
                    .padding(.bottom, 60)
                }
            } else if let currentLink = viewModel.gameState.currentLink {
                // Game screen
                GeometryReader { screenGeometry in
                    ZStack {
                        // State 1: "That is correct" message - handled separately as overlay

                        // State 2: Info overlay (clue + artist/song + song info)
                        if viewModel.showingSongInfo {
                            VStack(spacing: 0) {
                                // Close button only
                                HStack {
                                    Button("✕") {
                                        viewModel.endGame()
                                        dismiss()
                                    }
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                                // Centered info card
                                VStack {
                                    Spacer()

                                    VStack(spacing: 16) {
                                        // The solved clue at top
                                        Text(viewModel.solvedClueText)
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity)

                                        Divider()
                                            .background(Color.white.opacity(0.3))

                                        // Song title and artist in middle
                                        VStack(spacing: 4) {
                                            Text(viewModel.currentSongTitle)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                                .multilineTextAlignment(.center)

                                            Text(viewModel.currentArtistName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }

                                        // Song info text at bottom - full text with wrapping
                                        if !viewModel.solvedSongInfoText.isEmpty {
                                            Divider()
                                                .background(Color.white.opacity(0.3))

                                            Text(viewModel.solvedSongInfoText)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineSpacing(5)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                        }
                                    }
                                    .padding(20)
                                    .frame(maxWidth: screenGeometry.size.width - 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.black.opacity(0.75))
                                    )

                                    Spacer()
                                }
                            }
                            .transition(.opacity.animation(.easeInOut(duration: 1.5)))
                        }

                        // State 3: Waiting for queued song (blank - just album art)
                        else if viewModel.waitingForNextSong {
                            VStack {
                                // Close button only
                                HStack {
                                    Button("✕") {
                                        viewModel.endGame()
                                        dismiss()
                                    }
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                Spacer()
                            }
                        }

                        // State 4: "That is correct" showing (hide clue/input, just show close button)
                        else if viewModel.showingCorrectMessage {
                            VStack {
                                // Close button only
                                HStack {
                                    Button("✕") {
                                        viewModel.endGame()
                                        dismiss()
                                    }
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                Spacer()
                            }
                        }

                        // State 5: Normal clue display
                        else {
                            VStack(spacing: 0) {
                                // Header: Close + Hard Mode | Hint button
                                HStack {
                                    HStack(spacing: 12) {
                                        Button("✕") {
                                            viewModel.endGame()
                                            dismiss()
                                        }
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2)

                                        // Hard Mode Toggle
                                        Button {
                                            viewModel.toggleHardMode()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: viewModel.hardMode ? "flame.fill" : "flame")
                                                    .font(.system(size: 12))
                                                Text("Hard")
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .foregroundColor(viewModel.hardMode ? .orange : .white.opacity(0.7))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(viewModel.hardMode ? Color.orange.opacity(0.3) : Color.black.opacity(0.4))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(viewModel.hardMode ? Color.orange : Color.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                        }
                                    }

                                    Spacer()

                                    // Hint Button
                                    HintButton(
                                        isEnabled: viewModel.hintTimerActive,
                                        secondsRemaining: viewModel.secondsUntilHint,
                                        hintLevel: viewModel.hintLevel,
                                        hardMode: viewModel.hardMode,
                                        onTap: { viewModel.requestHint() }
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 8)

                                // Centered clue card
                                VStack {
                                    Spacer()

                                    VStack(spacing: 16) {
                                        // Clue section
                                        VStack(spacing: 8) {
                                            Text("Clue to the next song")
                                                .font(.headline)
                                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                                            Text(currentLink.clue)
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                                .frame(maxWidth: .infinity)
                                        }

                                        // Hints Display (progressive)
                                        if viewModel.hintLevel != .none {
                                            Divider()
                                                .background(Color.white.opacity(0.3))

                                            HintDisplayView(
                                                hintLevel: viewModel.hintLevel,
                                                hint1: currentLink.hint1,
                                                hint2: currentLink.hint2,
                                                multipleChoiceOptions: currentLink.multipleChoiceOptions,
                                                onSelectOption: { option in
                                                    viewModel.selectMultipleChoiceOption(option)
                                                }
                                            )
                                        }
                                    }
                                    .padding(20)
                                    .frame(maxWidth: screenGeometry.size.width - 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.black.opacity(0.75))
                                    )
                                    .animation(.easeInOut(duration: 0.5), value: viewModel.hintLevel)

                                    Spacer()
                                }

                                // Answer input (fixed at bottom)
                                VStack(spacing: 12) {
                                    TextField("Your answer...", text: $viewModel.currentAnswer)
                                        .font(.system(size: 18))
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.black.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(.white)
                                        .autocorrectionDisabled()

                                    Button {
                                        Task {
                                            await viewModel.submitAnswer()
                                        }
                                    } label: {
                                        Text("Submit")
                                            .font(.headline)
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                                            )
                                    }
                                    .disabled(viewModel.currentAnswer.isEmpty || viewModel.isCheckingAnswer)
                                    .opacity(viewModel.currentAnswer.isEmpty ? 0.5 : 1.0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                            .transition(.opacity.animation(.easeInOut(duration: 1.5)))
                        }
                    }
                    .animation(.easeInOut(duration: 1.5), value: viewModel.showingCorrectMessage)
                    .animation(.easeInOut(duration: 1.5), value: viewModel.showingSongInfo)
                    .animation(.easeInOut(duration: 1.5), value: viewModel.waitingForNextSong)
                }
            }

            // Waiting for next song - subtle indicator at bottom
            if viewModel.waitingForNextSong {
                GeometryReader { geometry in
                    VStack {
                        Spacer()

                        VStack(spacing: 8) {
                            // Progress bar
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)

                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .frame(width: (geometry.size.width - 72) * viewModel.playbackProgress, height: 4)
                            }
                            .frame(height: 4)

                            // Countdown message when near end
                            if viewModel.isNearEndOfSong {
                                Text("Next clue in \(viewModel.secondsUntilNextClue)s...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .transition(.opacity)
                            } else {
                                Text("Song queued - enjoy the music!")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(width: geometry.size.width - 32)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.bottom, 100)
                    }
                    .frame(width: geometry.size.width)
                }
                .animation(.easeInOut, value: viewModel.isNearEndOfSong)
            }

            // "That is correct" message - fixed at top, ignores keyboard
            if viewModel.showingCorrectMessage {
                VStack {
                    Text("That is correct!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.top, 100)

                    Spacer()
                }
                .ignoresSafeArea(.keyboard)
                .transition(.opacity.animation(.easeInOut(duration: 1.0)))
            }

            // Now Playing bar - shown at bottom when music is playing
            if viewModel.isSongPlaying && !viewModel.currentSongTitle.isEmpty && !viewModel.showingCompletionScreen {
                VStack {
                    Spacer()
                    NowPlayingBar(
                        songTitle: viewModel.currentSongTitle,
                        artistName: viewModel.currentArtistName,
                        progress: viewModel.playbackProgress,
                        isPlaying: viewModel.isSongPlaying
                    )
                }
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.isSongPlaying)
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .task {
            await viewModel.startGame()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // Default gradient background
    private var defaultGradientBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.1, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

}
