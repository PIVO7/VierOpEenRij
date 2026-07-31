import SwiftUI

/// Eén speelsteen in de speelgoedstijl: een dikke rand, een richel zoals op
/// de echte plastic schijfjes, en een hard schaduwtje voor de dikte.
struct DiscView: View {
    /// 0 = koraal (de beginner), 1 = amber — zoals rood en geel op het echte
    /// spel.
    var colorIndex: Int
    /// De diameter. Expliciet meegegeven — elke plek kent zijn maat toch al,
    /// en zo staat er geen GeometryReader per steen (42 op een vol bord).
    var size: CGFloat
    var depth: CGFloat = 0

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    @MainActor static var colors: [Color] {
        [AppTheme.coral, AppTheme.amber]
    }

    private var color: Color {
        Self.colors[colorIndex % Self.colors.count]
    }

    var body: some View {
        ZStack {
            if depth > 0 {
                Circle()
                    .fill(AppTheme.ink)
                    .offset(y: depth)
            }
            Circle()
                .fill(color)
            Circle()
                .strokeBorder(AppTheme.ink, lineWidth: max(size * 0.055, 1.5))
            // De richel: een dunne inktring iets binnen de rand.
            Circle()
                .strokeBorder(AppTheme.ink.opacity(0.35), lineWidth: max(size * 0.03, 1))
                .padding(size * 0.16)
            // Niet alleen kleur als onderscheid: met Onderscheid zonder
            // kleur krijgt elke speler ook een eigen vormpje op de steen.
            if differentiateWithoutColor {
                Image(systemName: colorIndex % 2 == 0 ? "circle.fill" : "square.fill")
                    .font(.system(size: size * 0.28, weight: .black))
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        DiscView(colorIndex: 0, size: 60)
        DiscView(colorIndex: 1, size: 60, depth: 4)
    }
    .padding()
    .background(AppTheme.cream)
}
