import SwiftUI

struct PlaylistRowView: View {
    let rowNumber: Int
    @Binding var link: ChainLink
    let onSearchMusic: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Row number + delete
            VStack(spacing: 4) {
                Text("\(rowNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red.opacity(0.7))
                .help("Delete row")
            }
            .frame(width: 35)

            // Clue
            charLimitedTextEditor(
                text: $link.clue,
                placeholder: "Clue",
                maxLength: ChainLink.maxClueLength,
                width: 160
            )

            // Hint 1
            charLimitedTextEditor(
                text: $link.hint1,
                placeholder: "Hint 1",
                maxLength: ChainLink.maxHint1Length,
                width: 130
            )

            // Hint 2 (optional)
            charLimitedTextEditor(
                text: Binding(
                    get: { link.hint2 ?? "" },
                    set: { link.hint2 = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "Hint 2 (opt)",
                maxLength: ChainLink.maxHint2Length,
                width: 130
            )

            // MC Options (2x2 grid)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    mcOptionField(index: 0, label: "A")
                    mcOptionField(index: 1, label: "B")
                }
                HStack(spacing: 4) {
                    mcOptionField(index: 2, label: "C")
                    mcOptionField(index: 3, label: "D")
                }
            }
            .frame(width: 200)

            // Correct Answers
            VStack(alignment: .trailing, spacing: 2) {
                TextField("e.g. Journey, journey", text: Binding(
                    get: { link.correctAnswers.joined(separator: ", ") },
                    set: { link.correctAnswers = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 130)

                Text("\(link.correctAnswers.count) answer(s)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // ISRC + Search
            VStack(alignment: .leading, spacing: 4) {
                TextField("ISRC", text: $link.isrc)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .frame(width: 100)

                Button {
                    onSearchMusic()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 110)

            // Song Info
            charLimitedTextEditor(
                text: Binding(
                    get: { link.songInfoText ?? "" },
                    set: { link.songInfoText = $0.isEmpty ? nil : $0 }
                ),
                placeholder: "Song info (opt)",
                maxLength: ChainLink.maxSongInfoLength,
                width: 140
            )

            // Album Art preview
            if let image = link.albumArtImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
            }

            // Status indicator
            VStack {
                if link.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 25)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func charLimitedTextEditor(text: Binding<String>, placeholder: String, maxLength: Int, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            TextEditor(text: text)
                .font(.system(size: 11))
                .frame(width: width, height: 60)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(text.wrappedValue.count > maxLength ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if text.wrappedValue.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.leading, 4)
                                .padding(.top, 4)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )

            Text("\(text.wrappedValue.count)/\(maxLength)")
                .font(.system(size: 9))
                .foregroundColor(text.wrappedValue.count > maxLength ? .red : .secondary)
        }
    }

    private func mcOptionField(index: Int, label: String) -> some View {
        let option = bindingForMCOption(index)
        let isOverLimit = option.wrappedValue.count > ChainLink.maxMCOptionLength

        return HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 12)

            TextField("", text: option)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
                .frame(width: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOverLimit ? Color.red : Color.clear, lineWidth: 1)
                )
        }
    }

    private func bindingForMCOption(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < link.multipleChoiceOptions.count else { return "" }
                return link.multipleChoiceOptions[index]
            },
            set: { newValue in
                while link.multipleChoiceOptions.count <= index {
                    link.multipleChoiceOptions.append("")
                }
                link.multipleChoiceOptions[index] = newValue
            }
        )
    }
}

#Preview {
    PlaylistRowView(
        rowNumber: 1,
        link: .constant(ChainLink.example),
        onSearchMusic: {},
        onDelete: {}
    )
    .frame(width: 1100)
}
