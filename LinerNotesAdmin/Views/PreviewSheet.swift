import SwiftUI

struct PreviewSheet: View {
    let hunt: TreasureHunt
    @Binding var selectedLinkIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(hunt.links.enumerated()), id: \.offset) { index, link in
                        ChainLinkPreviewCard(
                            linkNumber: index + 1,
                            link: link,
                            onEdit: {
                                selectedLinkIndex = index
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }

            footer
        }
        .frame(width: 700, height: 600)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hunt.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if !hunt.description.isEmpty {
                        Text(hunt.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()
        }
        .padding()
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()

            HStack {
                if hunt.isComplete {
                    Label("All \(hunt.links.count) links complete", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                } else {
                    Label("\(Int(hunt.completionPercentage))% complete (\(hunt.links.filter(\.isValid).count)/\(hunt.links.count))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.headline)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct ChainLinkPreviewCard: View {
    let linkNumber: Int
    let link: ChainLink
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Link #\(linkNumber)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(link.isValid ? Color.green : Color.orange)
                    .cornerRadius(12)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            HStack(alignment: .top, spacing: 16) {
                if let image = link.albumArtImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(link.clue.isEmpty ? "No clue" : link.clue)
                            .font(.body)
                            .foregroundColor(link.clue.isEmpty ? .secondary : .primary)
                    }

                    if !link.hint1.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hint 1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(link.hint1)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }

                    if let hint2 = link.hint2, !hint2.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hint 2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(hint2)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }

                    if !link.correctAnswers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Answer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            HStack {
                                ForEach(link.correctAnswers.prefix(3), id: \.self) { answer in
                                    Text(answer)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                if link.correctAnswers.count > 3 {
                                    Text("+\(link.correctAnswers.count - 3)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if !link.isrc.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ISRC")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(link.isrc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontDesign(.monospaced)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
