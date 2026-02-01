import SwiftUI

struct ChainLinkListItemView: View {
    let linkNumber: Int
    let link: ChainLink
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(linkNumber)")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)

            if let image = link.albumArtImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(link.clue.isEmpty ? "No clue" : link.clue)
                    .font(.body)
                    .foregroundColor(link.clue.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !link.correctAnswers.isEmpty {
                    Text(link.correctAnswers.first!)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusIcon
                .font(.title3)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if link.isValid {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if !link.clue.isEmpty || !link.isrc.isEmpty || !link.correctAnswers.isEmpty {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        } else {
            Image(systemName: "circle")
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

#Preview {
    VStack {
        ChainLinkListItemView(
            linkNumber: 1,
            link: ChainLink.example,
            isSelected: true
        )

        ChainLinkListItemView(
            linkNumber: 2,
            link: ChainLink.empty,
            isSelected: false
        )
    }
    .padding()
}
