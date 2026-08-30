import SwiftUI

/// Het rek als vormentaal van het startscherm: geen golvende randen maar
/// strakke banden met uitgestanste kijkgaten — het rek is stevig, en juist
/// die strakheid onderscheidt dit spel van zijn golvende broertjes.

/// Eén rij kijkgaten: open gaten tonen de achtergrondkleur van het rek,
/// gevulde gaten dragen een speelsteen.
struct RackHoleRow: View {
    var holeSize: CGFloat
    var count = 7
    /// Positie → schijfkleurindex; posities zonder waarde blijven open.
    var filled: [Int: Int] = [:]

    var body: some View {
        HStack(spacing: holeSize * 0.5) {
            ForEach(0..<count, id: \.self) { hole in
                if let colorIndex = filled[hole] {
                    DiscView(colorIndex: colorIndex, size: holeSize)
                } else {
                    Circle()
                        .fill(AppTheme.cream)
                        .overlay {
                            Circle()
                                .strokeBorder(AppTheme.ink, lineWidth: max(holeSize * 0.09, 1.5))
                        }
                        .frame(width: holeSize, height: holeSize)
                }
            }
        }
    }
}

/// De lichtblauwe rekband waarin de titel ligt: rechte inktranden en een rij
/// kijkgaten onder de tekst, waarvan er twee al een steen dragen.
struct RackBandView<Content: View>: View {
    var holeSize: CGFloat = 24
    var lineWidth: CGFloat = 3
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            content()
                .frame(maxWidth: .infinity)
            RackHoleRow(holeSize: holeSize, filled: [1: 0, 3: 1])
        }
        .padding(.vertical, 18)
        .background(Rectangle().fill(AppTheme.tintSky))
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.ink).frame(height: lineWidth)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.ink).frame(height: lineWidth)
        }
    }
}

/// Het rek onder aan het scherm: verzadigd blauw met twee rijen kijkgaten,
/// een paar gevallen stenen erin en twee stenen die er net in zakken. Puur
/// decor — ligt achter de inhoud en vangt geen aanrakingen.
struct RackView: View {
    var lineWidth: CGFloat = 3
    var height: CGFloat = 96

    var body: some View {
        Rectangle()
            .fill(AppTheme.sky)
            .overlay(alignment: .top) {
                Rectangle().fill(AppTheme.ink).frame(height: lineWidth)
            }
            .overlay {
                VStack(spacing: height * 0.12) {
                    RackHoleRow(holeSize: height * 0.27, filled: [3: 0])
                    RackHoleRow(holeSize: height * 0.27, filled: [0: 1, 2: 0, 3: 1, 5: 0])
                }
            }
            // Twee stenen zakken net het rek in: half boven de rand, alsof
            // de vorige beurt nog naklinkt.
            .overlay(alignment: .top) {
                HStack {
                    DiscView(colorIndex: 0, size: height * 0.26)
                        .padding(.leading, height * 0.85)
                    Spacer()
                    DiscView(colorIndex: 1, size: height * 0.26)
                        .padding(.trailing, height * 1.2)
                }
                .offset(y: -height * 0.13)
            }
            .frame(height: height)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 40) {
        RackBandView {
            Text(verbatim: "Vier op een rij!")
                .font(AppTheme.rounded(34))
                .foregroundStyle(AppTheme.ink)
        }
        Spacer()
        RackView()
    }
    .background(AppTheme.cream)
    .ignoresSafeArea(edges: .bottom)
    .appMetrics()
}
