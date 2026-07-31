import SwiftUI

/// Het anker van het startscherm: twee grote speelstenen boven de titel.
/// Tikken laat ze wiebelen en van kleur wisselen — puur voor de fun.
struct HomeHeroView: View {
    @Environment(\.metrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var swapped = false
    @State private var wiggle = 0

    var body: some View {
        Button(action: tumble) {
            HStack(spacing: -m.discSize * 0.22) {
                heroDisc(colorIndex: swapped ? 1 : 0, tilt: -9)
                    .zIndex(1)
                heroDisc(colorIndex: swapped ? 0 : 1, tilt: 8)
                    .offset(y: m.discSize * 0.16)
            }
            .rotationEffect(.degrees(wiggle.isMultiple(of: 2) ? 0 : 3))
            .animation(.spring(response: 0.3, dampingFraction: 0.35), value: wiggle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Twee speelstenen")
        .accessibilityHint("Tik om ze te laten wisselen")
    }

    private func heroDisc(colorIndex: Int, tilt: Double) -> some View {
        DiscView(colorIndex: colorIndex, depth: m.depth)
            .frame(width: m.discSize * 1.15, height: m.discSize * 1.15)
            .rotationEffect(.degrees(tilt))
    }

    private func tumble() {
        swapped.toggle()
        if !reduceMotion {
            wiggle += 1
        }
        SoundPlayer.shared.play(.drop)
    }
}

#Preview {
    HomeHeroView()
        .padding(40)
        .background(AppTheme.cream)
        .appMetrics()
}
