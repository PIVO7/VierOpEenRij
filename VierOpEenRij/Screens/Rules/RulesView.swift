import SwiftUI

/// De spelregels op kindhoogte: hoe een beurt werkt en hoe je wint.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            ThemedBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: m.gutter * 1.4) {
                    HStack {
                        Text("Hoe werkt het?")
                            .font(AppTheme.rounded(m.titleSize * 0.62))
                            .foregroundStyle(AppTheme.headline)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Label("Sluiten", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                                .font(.system(size: m.captionSize + 2, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: m.tapTarget, height: m.tapTarget)
                        }
                        .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: m.shallowDepth, border: m.thinBorder))
                    }

                    section("ZO SPEEL JE") {
                        card {
                            bullet("hand.tap.fill", String(localized: "Tik op een kolom en je steen valt naar het laagste vrije vakje."))
                            bullet("arrow.triangle.2.circlepath", String(localized: "Om de beurt: eerst de ene kleur, dan de andere."))
                            bullet("square.grid.3x3.fill", String(localized: "Het bord heeft 7 kolommen en 6 rijen. Een volle kolom kan niet meer."))
                        }
                    }

                    section("ZO WIN JE") {
                        card {
                            bullet("checkmark.circle.fill", String(localized: "Krijg als eerste vier stenen van jouw kleur op een rij."))
                            bullet("arrow.up.and.down.and.arrow.left.and.right", String(localized: "Dat mag liggend, staand of schuin."))
                            bullet("equal.circle.fill", String(localized: "Is het bord vol zonder rij van vier? Dan is het gelijkspel."))
                        }
                    }

                    section("SLIMME TRUCJES") {
                        card {
                            bullet("lightbulb.fill", String(localized: "De middelste kolom is goud waard: daar passen de meeste rijtjes doorheen."))
                            bullet("eye.fill", String(localized: "Kijk ook naar de stenen van de ander — drie op een rij moet je meteen blokkeren!"))
                            bullet("arrow.uturn.backward", String(localized: "Per ongeluk getikt? Met Zet terug mag je vorige steen er weer uit."))
                        }
                    }
                }
                .padding(.horizontal, m.gutter * 1.3)
                .padding(.top, m.gutter)
                .padding(.bottom, m.gutter * 2)
                .frame(maxWidth: m.overlayMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: m.gutter * 0.6) {
            Image(systemName: icon)
                .font(.system(size: m.bodySize, weight: .black))
                .foregroundStyle(AppTheme.coral)
                .frame(width: m.bodySize * 1.5)

            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: m.gutter * 0.8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(m.gutter)
        .toyBlock(fill: AppTheme.card, radius: m.cardCorner, depth: m.depth, border: m.border)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.rounded(m.captionSize * 0.9))
                .kerning(1.4)
                .foregroundStyle(AppTheme.faint)
                .padding(.leading, 4)
            content()
        }
    }
}

#Preview {
    RulesView()
        .appMetrics()
}
