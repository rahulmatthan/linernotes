import SwiftUI

// MARK: - Design Constants
private enum Design {
    enum Mode {
        // Toggle to quickly revert this visual refresh.
        static let useRefinedTheme = true
    }

    // Typography scale - SF Pro Rounded
    enum Font {
        static let caption = SwiftUI.Font.system(size: 13, weight: .regular, design: .rounded)
        static let captionMedium = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)
        static let body = SwiftUI.Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = SwiftUI.Font.system(size: 17, weight: .medium, design: .default)
        static let title1 = SwiftUI.Font.system(size: 32, weight: .bold, design: .serif)
        static let display = SwiftUI.Font.system(size: 44, weight: .bold, design: .serif)
    }

    enum Spacing {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Colors {
        static let accent = Mode.useRefinedTheme
            ? Color(red: 0.94, green: 0.67, blue: 0.32)
            : Color(red: 1.0, green: 0.42, blue: 0.42)
        static let secondaryText = Mode.useRefinedTheme ? Color.white.opacity(0.82) : Color.white.opacity(0.7)
        static let cardBackground = Mode.useRefinedTheme ? Color.black.opacity(0.58) : Color.clear
        static let buttonTextOnAccent = Mode.useRefinedTheme ? Color.black.opacity(0.85) : Color.black
        static let buttonOutline = Mode.useRefinedTheme ? Color.white.opacity(0.26) : accent
    }
}

struct ContentView: View {
    // Navigation state
    enum NavigationState {
        case splash
        case onboardingWelcome
        case onboardingInstructions
        case onboardingSelectHunt
        case huntSelection
        case game
    }

    @State private var navigationState: NavigationState = .splash
    @State private var selectedHunt: TreasureHunt?
    @State private var savedProgress: SavedProgress?
    @State private var selectedHuntFileId: String?

    private var brandMark: some View {
        Image("BrandRecord")
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }

    var body: some View {
        ZStack {
            VinylGrooveBackground()

            switch navigationState {
            case .splash:
                splashScreen
            case .onboardingWelcome:
                onboardingWelcomeScreen
            case .onboardingInstructions:
                onboardingInstructionsScreen
            case .onboardingSelectHunt:
                onboardingSelectHuntScreen
            case .huntSelection:
                HuntSelectionView(
                    onHuntSelected: { hunt, progress, huntFileId in
                        selectedHunt = hunt
                        savedProgress = progress
                        selectedHuntFileId = huntFileId
                        navigationState = .game
                    },
                    onClose: {
                        navigationState = .splash
                    }
                )
                .transition(.opacity)
            case .game:
                if let hunt = selectedHunt {
                    GameView(
                        treasureHunt: hunt,
                        savedProgress: savedProgress,
                        huntFileId: selectedHuntFileId ?? hunt.name,
                        skipOnboarding: true,
                        onClose: {
                            selectedHunt = nil
                            savedProgress = nil
                            selectedHuntFileId = nil
                            navigationState = .huntSelection
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: navigationState)
    }


    // MARK: - Splash Screen

    private var splashScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                if Design.Mode.useRefinedTheme {
                    brandMark
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(Design.Colors.accent)
                }

                Text("LinerNotes")
                    .font(Design.Font.display)
                    .foregroundColor(.white)

                Text("A Musical Treasure Hunt")
                    .font(Design.Font.bodyMedium)
                    .foregroundColor(Design.Colors.secondaryText)
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.vertical, Design.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Design.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )

            Spacer()

            VStack(spacing: 16) {
                Button {
                    navigationState = .onboardingWelcome
                } label: {
                    Label("How to Play", systemImage: "questionmark.circle")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Design.Colors.buttonOutline, lineWidth: 1.5)
                        )
                }

                Button {
                    navigationState = .huntSelection
                } label: {
                        Label("Start Hunting", systemImage: "play.fill")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.buttonTextOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Design.Colors.accent,
                                                Design.Colors.accent.opacity(0.78)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Onboarding Screens

    private var skipButton: some View {
        Button {
            navigationState = .huntSelection
        } label: {
            Text("Skip")
                .font(Design.Font.bodyMedium)
                .foregroundColor(Design.Colors.accent)
                .padding(.horizontal, Design.Spacing.lg)
                .padding(.vertical, Design.Spacing.sm)
                .background(Capsule().fill(Design.Colors.accent.opacity(0.15)))
        }
    }

    private var onboardingWelcomeScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    if Design.Mode.useRefinedTheme {
                        brandMark
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(Design.Colors.accent)
                    }

                    Text("Welcome")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                }

                Text("This is Liner Notes, a musical treasure hunt where you have to solve clues one by one to unlock the next song. Each song is linked to the next one and it is up to you to uncover the link")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .padding(.horizontal, Design.Spacing.xxxl)

                Spacer()

                // Next button
                Button {
                    navigationState = .onboardingInstructions
                } label: {
                    Text("Next")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Design.Colors.buttonTextOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Design.Colors.accent)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }

            // Skip button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)
                Spacer()
            }
        }
        .transition(.opacity)
    }

    private var onboardingInstructionsScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 56, weight: .light))
                        .foregroundColor(Design.Colors.accent)

                    Text("How to Play")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                }

                Text("To unlock a new song you will need to solve a clue. If you can't figure it out with one clue, after about a minute you will get an additional hint. If the answer still escapes you you will be offered a multiple choice selection. Remember every song is connected to the next either by some common history, or the musicians who made them.")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .padding(.horizontal, Design.Spacing.xxxl)

                Spacer()

                // Next button
                Button {
                    navigationState = .onboardingSelectHunt
                } label: {
                    Text("Next")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Design.Colors.buttonTextOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Design.Colors.accent)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }

            // Skip button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)
                Spacer()
            }
        }
        .transition(.opacity)
    }

    private var onboardingSelectHuntScreen: some View {
        ZStack {
            VStack(spacing: Design.Spacing.xxxl) {
                Spacer()

                VStack(spacing: Design.Spacing.xl) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 56, weight: .light))
                        .foregroundColor(Design.Colors.accent)

                    Text("Select Your Hunt")
                        .font(Design.Font.title1)
                        .foregroundColor(.white)
                }

                Text("On the next screen you will be given the option to select the hunt you want to embark on. As you proceed you can, if you want, add the songs to a playlist or wait till the end and add the entire hunt to the playlist after you have completed your quest")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .padding(.horizontal, Design.Spacing.xxxl)

                Spacer()

                // Let's Go button
                Button {
                    navigationState = .huntSelection
                } label: {
                    Text("Let's Go")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Design.Colors.buttonTextOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Design.Colors.accent)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }

            // Skip button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.md)
                Spacer()
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    ContentView()
}
