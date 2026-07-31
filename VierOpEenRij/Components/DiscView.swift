import SwiftUI

/// Eén speelsteen in de speelgoedstijl: een dikke rand, een richel zoals op
/// de echte plastic schijfjes, en een hard schaduwtje voor de dikte.
struct DiscView: View {
    /// 0 = koraal (de beginner), 1 = amber — zoals rood en geel op het echte
    /// spel.
    var colorIndex: Int
    var depth: CGFloat = 0

    @MainActor static var colors: [Color] {
        [AppTheme.coral, AppTheme.amber]
    }

    private var color: Color {
        Self.colors[colorIndex % Self.colors.count]
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
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
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        DiscView(colorIndex: 0)
            .frame(width: 60, height: 60)
        DiscView(colorIndex: 1, depth: 4)
            .frame(width: 60, height: 60)
    }
    .padding()
    .background(AppTheme.cream)
}
