import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "music.note.list")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("LinerNotes")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Musical Treasure Hunt")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
