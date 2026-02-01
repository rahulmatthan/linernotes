import SwiftUI

struct NowPlayingBar: View {
    let songTitle: String
    let artistName: String
    let progress: Double
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Song info
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))

                VStack(alignment: .leading, spacing: 2) {
                    Text(songTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    // Progress
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .frame(width: geometry.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.7))
                .background(.ultraThinMaterial)
        )
    }
}

struct NowPlayingBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                NowPlayingBar(
                    songTitle: "A Hard Day's Night",
                    artistName: "The Beatles",
                    progress: 0.35,
                    isPlaying: true
                )
                Spacer()
            }
        }
    }
}
