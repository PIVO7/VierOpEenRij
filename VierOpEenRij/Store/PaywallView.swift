import SwiftUI

/// Het aankoopscherm van de Gezinsversie: wat je krijgt, één prijs, en een
/// ouder-poort vóór de kassa.
struct PaywallView: View {
    let entitlements: EntitlementStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.metrics) private var m

    @State private var gateQuestion: ParentalGateQuestion?
    @State private var pendingAction: (() async -> Void)?
    @State private var isBusy = false

    private var priceText: String {
        entitlements.familyProduct?.displayPrice ?? "…"
    }

    var body: some View {
        ZStack {
            AppTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: m.gutter) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Label("Sluiten", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                                .font(.system(size: m.captionSize + 2, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: m.tapTarget, height: m.tapTarget)
                        }
                        .buttonStyle(ToyButtonStyle(fill: .white, radius: m.cellCorner, depth: 3, border: m.thinBorder))
                    }

                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: m.titleSize, weight: .black))
                        .foregroundStyle(AppTheme.coral)

                    Text("Gezinsversie")
                        .font(AppTheme.rounded(m.titleSize * 0.7))
                        .foregroundStyle(AppTheme.headline)

                    Text("Eén keer kopen, voor het hele gezin — ook via Delen met gezin.")
                        .font(AppTheme.rounded(m.captionSize + 2, .bold))
                        .foregroundStyle(AppTheme.soft)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: m.gutter * 0.7) {
                        feature("graduationcap.fill", "Alle drie de tegenstanders: Dommel, Robbie en Professor Punt")
                        feature("paintpalette.fill", "Alle kleurenthema's: Snoep, Oceaan en Nacht")
                        feature("chart.bar.fill", "Statistieken per speler, met winreeks en snelste winst")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(m.gutter)
                    .toyBlock(fill: .white, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)

                    if entitlements.isFamilyUnlocked {
                        Label("Ontgrendeld — veel plezier!", systemImage: "checkmark.seal.fill")
                            .font(AppTheme.rounded(m.bodySize))
                            .foregroundStyle(AppTheme.mint)
                            .padding(.top, m.gutter)
                    } else {
                        Button {
                            askParent { await purchase() }
                        } label: {
                            Text("Ontgrendel voor \(priceText)")
                                .font(AppTheme.rounded(m.buttonTextSize * 0.8))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: m.buttonHeight * 0.85)
                        }
                        .buttonStyle(ToyButtonStyle(
                            fill: AppTheme.mint,
                            radius: m.cardCorner * 0.9,
                            depth: m.depth,
                            border: m.border
                        ))
                        .disabled(isBusy)

                        Button {
                            askParent { await entitlements.restorePurchases() }
                        } label: {
                            Text("Eerder gekocht? Zet terug")
                                .font(AppTheme.rounded(m.captionSize, .bold))
                                .foregroundStyle(AppTheme.soft)
                                .frame(minHeight: m.tapTarget)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                    }
                }
                .padding(.horizontal, m.gutter * 1.4)
                .padding(.bottom, m.gutter * 2)
                .frame(maxWidth: m.overlayMaxWidth)
                .frame(maxWidth: .infinity)
            }

            // De ouder-poort: verplicht voor de kindercategorie, en eerlijk
            // gezegd gewoon verstandig.
            if let question = gateQuestion {
                gateOverlay(question)
            }
        }
        .interactiveDismissDisabled(isBusy)
    }

    private func feature(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: m.gutter * 0.6) {
            Image(systemName: icon)
                .font(.system(size: m.bodySize, weight: .black))
                .foregroundStyle(AppTheme.coral)
                .frame(width: m.bodySize * 1.6)
            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func gateOverlay(_ question: ParentalGateQuestion) -> some View {
        ZStack {
            AppTheme.ink.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { closeGate() }

            VStack(spacing: m.gutter * 0.8) {
                Text("Vraag even aan papa of mama")
                    .font(AppTheme.rounded(m.bodySize + 2))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)

                Text(question.text)
                    .font(AppTheme.rounded(m.titleSize * 0.6))
                    .foregroundStyle(AppTheme.coral)

                HStack(spacing: m.gutter * 0.7) {
                    ForEach(question.options, id: \.self) { option in
                        Button {
                            answerGate(with: option, question: question)
                        } label: {
                            Text("\(option)")
                                .font(AppTheme.rounded(m.bodySize + 2))
                                .foregroundStyle(AppTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: m.tapTarget)
                        }
                        .buttonStyle(ToyButtonStyle(fill: .white, radius: m.cellCorner, depth: 3, border: m.thinBorder))
                    }
                }
            }
            .padding(m.gutter * 1.4)
            .toyBlock(fill: AppTheme.cream, radius: m.cardCorner + 4, depth: m.depth + 1, border: m.border)
            .frame(maxWidth: m.overlayMaxWidth * 0.82)
            .padding(m.gutter * 2)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    private func askParent(_ action: @escaping () async -> Void) {
        pendingAction = action
        withAnimation(.easeOut(duration: 0.15)) {
            gateQuestion = .make()
        }
    }

    private func answerGate(with option: Int, question: ParentalGateQuestion) {
        guard option == question.answer else {
            // Fout: nieuwe vraag, zodat gokken niet loont.
            gateQuestion = .make()
            return
        }
        let action = pendingAction
        closeGate()
        isBusy = true
        Task {
            await action?()
            isBusy = false
        }
    }

    private func closeGate() {
        withAnimation(.easeOut(duration: 0.15)) {
            gateQuestion = nil
        }
        pendingAction = nil
    }

    private func purchase() async {
        _ = await entitlements.purchaseFamily()
    }
}

#Preview {
    PaywallView(entitlements: EntitlementStore(previewUnlocked: false))
        .appMetrics()
}
