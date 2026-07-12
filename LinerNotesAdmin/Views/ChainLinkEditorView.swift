import SwiftUI

struct ChainLinkEditorView: View {
    @ObservedObject var viewModel: TreasureHuntViewModel
    @State private var editedLink: ChainLink
    @State private var newArtist: String = ""
    @State private var showingMusicSearch = false
    @State private var previewMode: PreviewMode = .clue
    @State private var isValidatingSong = false
    @State private var songValidationResult: SongValidationResult?

    private enum PreviewMode: String, CaseIterable, Identifiable {
        case clue = "Clue"
        case hint = "Hint"
        case correct = "Correct"
        case songInfo = "Song Info"

        var id: String { rawValue }
    }

    init(viewModel: TreasureHuntViewModel) {
        self.viewModel = viewModel
        self._editedLink = State(initialValue: viewModel.currentLink)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                clueSection

                hintSection

                multipleChoiceSection

                correctAnswersSection

                songSearchSection

                answerTextSection

                songStartInfoSection

                triviaSection

                previewSection

                actionButtons
            }
            .padding()
        }
        .onChange(of: viewModel.selectedLinkIndex) { _, _ in
            editedLink = viewModel.currentLink
        }
        .onChange(of: editedLink) { _, newValue in
            viewModel.updateLink(at: viewModel.selectedLinkIndex, with: newValue)
        }
        .sheet(isPresented: $showingMusicSearch) {
            if #available(macOS 14.0, *) {
                MusicSearchSheet { isrc, artworkData, songTitle, artistName in
                    if let isrc = isrc {
                        editedLink.isrc = isrc
                    }
                    if let artworkData = artworkData {
                        editedLink.albumArtData = artworkData
                    }
                    // Store song title and artist for search fallback
                    editedLink.songTitle = songTitle
                    editedLink.artistName = artistName
                    // Also add artist to correct answers if not present
                    if !artistName.isEmpty && !editedLink.correctAnswers.contains(artistName) {
                        editedLink.correctAnswers.append(artistName)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain Link #\(viewModel.selectedLinkIndex + 1)")
                    .font(.title2)
                    .fontWeight(.bold)

                if editedLink.isValid {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                } else {
                    Label("Incomplete", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }
            }

            Spacer()
        }
    }

    // MARK: - Clue Section

    private var clueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "CLUE", icon: "questionmark.circle.fill", required: true)

            Text("The puzzle or question the player needs to solve")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $editedLink.clue)
                .font(.body)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(editedLink.clue.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
                )

            characterCounter(current: editedLink.clue.count, max: ChainLink.maxClueLength)
        }
    }

    // MARK: - Hint Section

    private var hintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "HINT", icon: "lightbulb.fill", required: true)

            Text("Hint shown after 60 seconds to help the player")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $editedLink.hint1)
                .font(.body)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            characterCounter(current: editedLink.hint1.count, max: ChainLink.maxHint1Length)
        }
    }

    // MARK: - Multiple Choice Section

    private var multipleChoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "MULTIPLE CHOICE OPTIONS", icon: "list.bullet.circle.fill", required: true)

            Text("Four options shown when player needs help (one must be correct)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                mcOptionField(index: 0, label: "A")
                mcOptionField(index: 1, label: "B")
                mcOptionField(index: 2, label: "C")
                mcOptionField(index: 3, label: "D")
            }
        }
    }

    private func mcOptionField(index: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextField("Option \(label)", text: bindingForMCOption(index))
                .textFieldStyle(.roundedBorder)

            characterCounter(
                current: (index < editedLink.multipleChoiceOptions.count ? editedLink.multipleChoiceOptions[index] : "").count,
                max: ChainLink.maxMCOptionLength
            )
        }
    }

    private func bindingForMCOption(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < editedLink.multipleChoiceOptions.count else { return "" }
                return editedLink.multipleChoiceOptions[index]
            },
            set: { newValue in
                while editedLink.multipleChoiceOptions.count <= index {
                    editedLink.multipleChoiceOptions.append("")
                }
                editedLink.multipleChoiceOptions[index] = newValue
            }
        )
    }

    // MARK: - Correct Answers Section

    private var correctAnswersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "CORRECT ANSWERS", icon: "checkmark.circle.fill", required: true)

            Text("Add multiple variations (e.g., 'Pink Floyd', 'pink floyd')")
                .font(.caption)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(Array(editedLink.correctAnswers.enumerated()), id: \.offset) { index, answer in
                    HStack(spacing: 4) {
                        Text(answer)
                            .font(.body)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                        Button {
                            editedLink.correctAnswers.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(12)
                }
            }

            HStack {
                TextField("Add answer variant...", text: $newArtist)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addArtist()
                    }

                Button("Add") {
                    addArtist()
                }
                .disabled(newArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if editedLink.correctAnswers.isEmpty {
                Text("At least one correct answer is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Song Search Section

    private var songSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "SONG", icon: "music.note", required: true)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ISRC")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("International Standard Recording Code", text: $editedLink.isrc)
                                .textFieldStyle(.roundedBorder)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(editedLink.isrc.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Song Title")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Song Title", text: Binding(
                                get: { editedLink.songTitle ?? "" },
                                set: { editedLink.songTitle = $0.isEmpty ? nil : $0 }
                            ))
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Artist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Artist Name", text: Binding(
                                get: { editedLink.artistName ?? "" },
                                set: { editedLink.artistName = $0.isEmpty ? nil : $0 }
                            ))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button {
                        showingMusicSearch = true
                    } label: {
                        Label("Search Music", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await validateSongID()
                            }
                        } label: {
                            if isValidatingSong {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Validating...")
                                }
                            } else {
                                Label("Validate Song ID", systemImage: "checkmark.shield")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isValidatingSong)

                        if let result = songValidationResult {
                            Label(
                                result.isValid ? "Valid" : "Needs Attention",
                                systemImage: result.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundColor(result.isValid ? .green : .orange)
                        }
                    }

                    if let result = songValidationResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(result.isValid ? .green : .orange)
                    }

                    if editedLink.isrc.isEmpty {
                        Text("ISRC is required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Album Art Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Album Art")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let image = editedLink.albumArtImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 120, maxHeight: 120)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("No art")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Answer Text Section

    private var answerTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "ANSWER TEXT", icon: "text.bubble.fill", required: false)

            Text("Shown in the \"Correct\" overlay when the player solves this clue")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: Binding(
                get: { editedLink.answerText ?? "" },
                set: { editedLink.answerText = $0.isEmpty ? nil : $0 }
            ))
                .font(.body)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            characterCounter(current: editedLink.answerText?.count ?? 0, max: ChainLink.maxAnswerTextLength)
        }
    }

    // MARK: - Song Start Info Section

    private var songStartInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "SONG START INFO", icon: "play.circle.fill", required: false)

            Text("Shown for 10 seconds when this song starts playing (after being queued)")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: Binding(
                get: { editedLink.songStartInfo ?? "" },
                set: { editedLink.songStartInfo = $0.isEmpty ? nil : $0 }
            ))
                .font(.body)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            characterCounter(current: editedLink.songStartInfo?.count ?? 0, max: ChainLink.maxSongStartInfoLength)
        }
    }

    // MARK: - Trivia Section

    private var triviaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "TRIVIA", icon: "text.bubble.fill", required: false)

            Text("Shown while the player waits for the queued song to play (cycles through items)")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(Array(editedLink.triviaItems.enumerated()), id: \.offset) { index, _ in
                triviaItemField(index: index)
            }

            if editedLink.triviaItems.count < ChainLink.maxTriviaItems {
                Button {
                    editedLink.triviaItems.append("")
                } label: {
                    Label("Add Trivia Item", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }

            if editedLink.triviaItems.count >= ChainLink.maxTriviaItems {
                Text("Maximum \(ChainLink.maxTriviaItems) trivia items reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func triviaItemField(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Trivia \(index + 1)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    editedLink.triviaItems.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: Binding(
                get: {
                    guard index < editedLink.triviaItems.count else { return "" }
                    return editedLink.triviaItems[index]
                },
                set: { newValue in
                    guard index < editedLink.triviaItems.count else { return }
                    editedLink.triviaItems[index] = newValue
                }
            ))
                .font(.body)
                .frame(minHeight: 60)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            characterCounter(
                current: index < editedLink.triviaItems.count ? editedLink.triviaItems[index].count : 0,
                max: ChainLink.maxTriviaItemLength
            )
        }
    }

    // MARK: - Player-Style Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "PLAYER PREVIEW", icon: "eye.fill", required: false)

            Text("Approximate view of how this clue and related text will appear in the player experience.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Preview Mode", selection: $previewMode) {
                Text("Clue").tag(PreviewMode.clue)
                Text("Hint").tag(PreviewMode.hint)
                Text("Correct").tag(PreviewMode.correct)
                Text("Song Info").tag(PreviewMode.songInfo)
            }
            .pickerStyle(.segmented)

            previewCard
        }
    }

    private var previewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Clue #\(viewModel.selectedLinkIndex + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                    )

                Spacer()
            }

            HStack(alignment: .top, spacing: 16) {
                if let image = editedLink.albumArtImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.5))
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    switch previewMode {
                    case .clue:
                        previewClueText
                    case .hint:
                        previewClueText
                        previewHintAndOptions
                    case .correct:
                        previewCorrectOverlay
                    case .songInfo:
                        previewSongStartInfo
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.12),
                            Color(red: 0.13, green: 0.13, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var previewClueText: some View {
        let sentences = splitIntoSentences(editedLink.clue)

        return VStack(alignment: .leading, spacing: 8) {
            if let first = sentences.first {
                Text(first)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sentences.count > 1 {
                Text(sentences.dropFirst().joined(separator: " "))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var previewHintAndOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !editedLink.hint1.isEmpty {
                Text("HINT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                    .textCase(.uppercase)

                Text(editedLink.hint1)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }

            if !editedLink.multipleChoiceOptions.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(editedLink.multipleChoiceOptions.enumerated()), id: \.offset) { index, option in
                        if !option.isEmpty {
                            HStack(spacing: 8) {
                                Text(String(UnicodeScalar(65 + index)!))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(option)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
    }

    private var previewCorrectOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Correct")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))

            let text = editedLink.answerText?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            } else if !editedLink.correctAnswers.isEmpty {
                Text(editedLink.correctAnswers.joined(separator: ", "))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Text("Answer text will be shown here when the player solves this clue.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var previewSongStartInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOW PLAYING")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                .textCase(.uppercase)

            if let title = editedLink.songTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            if let artist = editedLink.artistName, !artist.isEmpty {
                Text(artist)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            if let info = editedLink.songStartInfo, !info.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.2))

                Text(info)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            } else {
                Text("Short intro or context shown when this song starts will appear here.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if editedLink.albumArtData != nil {
                Button(role: .destructive) {
                    editedLink.albumArtData = nil
                } label: {
                    Label("Remove Album Art", systemImage: "trash")
                }
            }

            Spacer()
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, icon: String, required: Bool) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)

            if required {
                Text("*")
                    .foregroundColor(.red)
                    .font(.headline)
            }
        }
    }

    private func characterCounter(current: Int, max: Int) -> some View {
        HStack {
            Spacer()
            Text("\(current)/\(max)")
                .font(.caption)
                .foregroundColor(current > max ? .red : .secondary)
        }
    }

    private func addArtist() {
        let trimmed = newArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !editedLink.correctAnswers.contains(trimmed) else {
            newArtist = ""
            return
        }
        editedLink.correctAnswers.append(trimmed)
        newArtist = ""
    }

    @MainActor
    private func validateSongID() async {
        isValidatingSong = true
        defer { isValidatingSong = false }

        songValidationResult = await MusicKitService.shared.validateSongIdentifier(
            isrc: editedLink.isrc,
            songTitle: editedLink.songTitle,
            artistName: editedLink.artistName
        )
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let sentenceEndings = CharacterSet(charactersIn: ".!?")
        var sentences: [String] = []
        var currentSentence = ""

        for char in trimmed {
            currentSentence.append(char)

            if let scalar = char.unicodeScalars.first, sentenceEndings.contains(scalar) {
                sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
                currentSentence = ""
            }
        }

        if !currentSentence.isEmpty {
            sentences.append(currentSentence.trimmingCharacters(in: .whitespaces))
        }

        return sentences.filter { !$0.isEmpty }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
