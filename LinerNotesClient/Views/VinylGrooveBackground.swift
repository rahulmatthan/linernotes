import SwiftUI

/// A subtle vinyl record groove texture background
/// Features concentric circles with varying opacity to create depth and visual interest
/// Optimized for dark themes with minimal performance impact
struct VinylGrooveBackground: View {
    // Groove appearance parameters
    private let grooveCount: Int = 180
    private let baseOpacity: Double = 0.02
    private let maxOpacity: Double = 0.06
    private let strokeWidth: CGFloat = 0.8

    // Animation state for subtle rotation
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = max(geometry.size.width, geometry.size.height) * 0.8

            ZStack {
                // Base gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.1),
                        Color(red: 0.14, green: 0.125, blue: 0.125)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Vinyl grooves layer
                Canvas { context, size in
                    // Create concentric circles with varying opacity
                    for i in 0..<grooveCount {
                        let progress = Double(i) / Double(grooveCount)
                        let radius = maxRadius * progress

                        // Calculate opacity with subtle variations
                        // Creates depth by making some grooves more visible than others
                        let opacityVariation = sin(progress * .pi * 12) * 0.5 + 0.5
                        let opacity = baseOpacity + (maxOpacity - baseOpacity) * opacityVariation

                        // Create the circle path
                        let circlePath = Path { path in
                            path.addEllipse(in: CGRect(
                                x: center.x - radius,
                                y: center.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            ))
                        }

                        // Draw the groove
                        context.stroke(
                            circlePath,
                            with: .color(.white.opacity(opacity)),
                            lineWidth: strokeWidth
                        )
                    }

                    // Add subtle radial "scratches" for authenticity
                    drawRadialScratches(context: context, center: center, maxRadius: maxRadius)
                }
                .rotationEffect(.degrees(rotation))
                .blur(radius: 0.3) // Subtle blur for smooth appearance

                // Noise overlay for vinyl grain texture
                noiseOverlay
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Extremely slow rotation for subtle movement
            withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    /// Draws subtle radial lines to simulate vinyl imperfections
    private func drawRadialScratches(context: GraphicsContext, center: CGPoint, maxRadius: CGFloat) {
        let scratchCount = 24

        for i in 0..<scratchCount {
            let angle = (Double(i) / Double(scratchCount)) * 2 * .pi
            let startRadius = maxRadius * 0.3
            let endRadius = maxRadius * 0.95

            let startX = center.x + cos(angle) * startRadius
            let startY = center.y + sin(angle) * startRadius
            let endX = center.x + cos(angle) * endRadius
            let endY = center.y + sin(angle) * endRadius

            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            context.stroke(
                path,
                with: .color(.white.opacity(0.008)),
                lineWidth: 0.5
            )
        }
    }

    /// Subtle noise overlay to add vinyl grain texture
    private var noiseOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.01), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.overlay)
            .opacity(0.15)
    }
}

#Preview("Vinyl Groove Background") {
    VinylGrooveBackground()
}

#Preview("With Content Overlay") {
    ZStack {
        VinylGrooveBackground()

        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))

            Text("LinerNotes")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Testing vinyl texture with content")
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
