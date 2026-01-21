import SwiftUI

struct AdminContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "gearshape.2")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("LinerNotes Admin")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Manage Treasure Hunts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    AdminContentView()
}
