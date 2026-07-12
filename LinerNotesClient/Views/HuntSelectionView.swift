import SwiftUI

// MARK: - Design Constants (matching GameView)
private enum Design {
    enum Mode {
        static let useRefinedTheme = true
    }

    // Typography scale - SF Pro Rounded
    enum Font {
        static let caption = SwiftUI.Font.system(size: 13, weight: .regular, design: .rounded)
        static let captionMedium = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)
        static let body = SwiftUI.Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = SwiftUI.Font.system(size: 17, weight: .medium, design: .default)
        static let title3 = SwiftUI.Font.system(size: 19, weight: .regular, design: .default)
        static let title3Medium = SwiftUI.Font.system(size: 20, weight: .semibold, design: .serif)
        static let title2 = SwiftUI.Font.system(size: 22, weight: .semibold, design: .serif)
        static let title1 = SwiftUI.Font.system(size: 30, weight: .bold, design: .serif)
    }

    enum Spacing {
        static let xs: CGFloat = 4
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
        static let cardBackground = Mode.useRefinedTheme ? Color.black.opacity(0.62) : Color.black.opacity(0.8)
        static let secondaryText = Mode.useRefinedTheme ? Color.white.opacity(0.82) : Color.white.opacity(0.7)
        static let tertiaryText = Mode.useRefinedTheme ? Color.white.opacity(0.62) : Color.white.opacity(0.5)
        static let border = Mode.useRefinedTheme ? Color.white.opacity(0.14) : Color.white.opacity(0.2)
        static let inProgress = Color.orange
        static let completed = Color(red: 0.41, green: 0.94, blue: 0.68)
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}

struct HuntSelectionView: View {
    @StateObject private var viewModel = HuntSelectionViewModel()
    @Environment(\.dismiss) private var dismiss

    // Callbacks for hunt selection
    let onHuntSelected: (TreasureHunt, SavedProgress?, String) -> Void
    let onClose: () -> Void

    @State private var selectedHuntInfo: HuntInfo?
    @State private var isLoadingHunt = false
    @State private var showingContinuePrompt = false
    @State private var pendingHunt: TreasureHunt?
    @State private var pendingProgress: SavedProgress?
    @State private var pendingHuntId: String?

    private var brandMark: some View {
        Image("BrandRecord")
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    var body: some View {
        ZStack {
            VinylGrooveBackground()

            VStack(spacing: Design.Spacing.xxl) {
                header

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Design.Colors.accent))
                        .scaleEffect(1.5)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    errorView(message: error)
                    Spacer()
                } else {
                    huntList
                }
            }
            .padding(.top, Design.Spacing.xxl)

            // Loading overlay when fetching a specific hunt
            if isLoadingHunt {
                loadingOverlay
            }
        }
        .task {
            await viewModel.loadManifest()
        }
        .alert("Continue Game?", isPresented: $showingContinuePrompt) {
            Button("Continue") {
                if let hunt = pendingHunt, let huntId = pendingHuntId {
                    onHuntSelected(hunt, pendingProgress, huntId)
                }
                clearPendingState()
            }
            Button("Start New") {
                if let huntId = pendingHuntId {
                    viewModel.clearProgress(for: huntId)
                }
                if let hunt = pendingHunt, let huntId = pendingHuntId {
                    onHuntSelected(hunt, nil, huntId)
                }
                clearPendingState()
            }
            Button("Cancel", role: .cancel) {
                clearPendingState()
            }
        } message: {
            if let progress = pendingProgress {
                Text("You have saved progress at clue \(progress.currentLinkIndex + 1). Would you like to continue or start over?")
            }
        }
    }


    // MARK: - Header

    private var header: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.horizontal, Design.Spacing.xl)

            VStack(spacing: Design.Spacing.sm) {
                if Design.Mode.useRefinedTheme {
                    brandMark
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40, weight: .regular, design: .rounded))
                        .foregroundColor(Design.Colors.accent)
                }

                Text("Choose Your Hunt")
                    .font(Design.Font.title1)
                    .foregroundColor(.white)

                Text("Select a musical treasure hunt to begin")
                    .font(Design.Font.body)
                    .foregroundColor(Design.Colors.secondaryText)
            }
        }
    }

    // MARK: - Hunt List

    private var huntList: some View {
        ScrollView {
            LazyVStack(spacing: Design.Spacing.lg) {
                ForEach(viewModel.huntInfos) { huntInfo in
                    HuntCard(
                        huntInfo: huntInfo,
                        status: viewModel.getStatus(for: huntInfo.id)
                    )
                    .onTapGesture {
                        Task {
                            await selectHunt(huntInfo)
                        }
                    }
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.xxxl)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Design.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .regular, design: .rounded))
                .foregroundColor(Design.Colors.accent)

            Text("Unable to Load Hunts")
                .font(Design.Font.title3Medium)
                .foregroundColor(.white)

            Text(message)
                .font(Design.Font.body)
                .foregroundColor(Design.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadManifest()
                }
            } label: {
                Text("Try Again")
                    .font(Design.Font.bodyMedium)
                    .foregroundColor(.black)
                    .padding(.horizontal, Design.Spacing.xxl)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.accent)
                    .cornerRadius(Design.Radius.md)
            }
        }
        .padding(.horizontal, Design.Spacing.xxl)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: Design.Spacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Design.Colors.accent))
                    .scaleEffect(1.5)

                Text("Loading hunt...")
                    .font(Design.Font.body)
                    .foregroundColor(.white)
            }
            .padding(Design.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Colors.cardBackground)
            )
        }
    }

    // MARK: - Actions

    private func selectHunt(_ huntInfo: HuntInfo) async {
        isLoadingHunt = true
        defer { isLoadingHunt = false }

        // Load the hunt data
        guard let hunt = await viewModel.loadHunt(info: huntInfo) else {
            viewModel.errorMessage = "Failed to load hunt '\(huntInfo.name)'"
            return
        }

        // Check for saved progress
        if let progress = viewModel.getSavedProgress(for: huntInfo.id),
           progress.matches(hunt: hunt),
           !progress.isComplete {
            // Has valid in-progress save - prompt user
            pendingHunt = hunt
            pendingProgress = progress
            pendingHuntId = huntInfo.id
            showingContinuePrompt = true
        } else {
            // No progress or completed - start fresh
            onHuntSelected(hunt, nil, huntInfo.id)
        }
    }

    private func clearPendingState() {
        pendingHunt = nil
        pendingProgress = nil
        pendingHuntId = nil
    }
}

// MARK: - Hunt Card

struct HuntCard: View {
    let huntInfo: HuntInfo
    let status: HuntStatus

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Design.Spacing.xs) {
                    Text(huntInfo.name)
                        .font(Design.Font.title3Medium)
                        .foregroundColor(.white)

                    Text(huntInfo.description)
                        .font(Design.Font.body)
                        .foregroundColor(Design.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                statusIndicator
            }

            HStack {
                Label("\(huntInfo.songCount) songs", systemImage: "music.note")
                    .font(Design.Font.caption)
                    .foregroundColor(Design.Colors.tertiaryText)

                if let difficulty = huntInfo.difficulty {
                    Text("•")
                        .foregroundColor(Design.Colors.tertiaryText)

                    Text(difficulty)
                        .font(Design.Font.caption)
                        .foregroundColor(Design.Colors.tertiaryText)
                }

                Spacer()

                if case .inProgress(let progress) = status {
                    Text("\(Int(progress * 100))% complete")
                        .font(Design.Font.caption)
                        .foregroundColor(Design.Colors.inProgress)
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.lg)
                .fill(Design.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Radius.lg)
                        .stroke(statusBorderColor, lineWidth: 1)
                )
        )
    }

    private var statusIndicator: some View {
        Group {
            switch status {
            case .notStarted:
                Image(systemName: "circle")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(Design.Colors.tertiaryText)

            case .inProgress(let progress):
                ZStack {
                    Circle()
                        .stroke(Design.Colors.inProgress.opacity(0.3), lineWidth: 2.2)
                        .frame(width: 20, height: 20)

                    Circle()
                        .trim(from: 0, to: min(max(progress, 0), 1))
                        .stroke(
                            Design.Colors.inProgress,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 20, height: 20)
                }

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(Design.Colors.completed)
            }
        }
    }

    private var statusBorderColor: Color {
        switch status {
        case .notStarted:
            return Design.Colors.border
        case .inProgress:
            return Design.Colors.inProgress.opacity(0.5)
        case .completed:
            return Design.Colors.completed.opacity(0.5)
        }
    }
}

#Preview {
    HuntSelectionView(
        onHuntSelected: { _, _, _ in },
        onClose: {}
    )
}
