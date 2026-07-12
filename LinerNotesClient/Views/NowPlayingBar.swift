import SwiftUI

struct NowPlayingBar: View {
    let progress: Double

    // Design constants
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.42)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 3)

                // Progress fill
                Rectangle()
                    .fill(accentColor)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 3)
            }
        }
        .frame(height: 3)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            NowPlayingBar(progress: 0.4)
        }
    }
}
