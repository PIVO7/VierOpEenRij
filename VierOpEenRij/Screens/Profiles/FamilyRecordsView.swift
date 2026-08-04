import SwiftUI

/// De gezinsrecords: wie het record heeft, per categorie. Bewust alleen
/// hoogtepunten — nooit wie ergens de minste in is.
struct FamilyRecordsView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.metrics) private var m

    @State private var showPaywall = false

    /// Alleen profielen die al gespeeld hebben doen mee.
    private var contenders: [PlayerProfile] {
        profileStore.humanProfiles.filter { $0.gamesPlayed > 0 }
    }

    var body: some View {
        ZStack {
            AppTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: m.gutter) {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: m.titleSize * 0.9, weight: .black))
                            .foregroundStyle(AppTheme.amber)
                        Text("Gezinsrecords")
                            .font(AppTheme.rounded(m.titleSize * 0.6))
                            .foregroundStyle(AppTheme.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, m.gutter * 0.5)

                    if !entitlements.isFamilyUnlocked {
                        lockedCard
                    } else if contenders.isEmpty {
                        Text("Speel eerst een potje — daarna staan hier de records van het gezin.")
                            .font(AppTheme.rounded(m.bodySize, .bold))
                            .foregroundStyle(AppTheme.cardSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(m.gutter)
                            .toyBlock(fill: AppTheme.card, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)
                    } else {
                        recordRow(
                            title: String(localized: "Meeste overwinningen"),
                            icon: "crown.fill",
                            value: { $0.wins },
                            format: { String(localized: "\($0) keer gewonnen") }
                        )
                        recordRow(
                            title: String(localized: "Langste winreeks"),
                            icon: "flame.fill",
                            value: { $0.bestStreak },
                            format: { String(localized: "\($0) op rij") }
                        )
                        recordRow(
                            title: String(localized: "Snelste overwinning"),
                            icon: "bolt.fill",
                            value: { $0.fastestWin },
                            format: { String(localized: "\($0) stenen") },
                            // Hier wint juist het kleinste getal: hoe minder
                            // stenen, hoe knapper de overwinning.
                            best: { $0.filter { $0 > 0 }.min() }
                        )
                        recordRow(
                            title: String(localized: "Meeste potjes"),
                            icon: "circle.grid.3x3.fill",
                            value: { $0.gamesPlayed },
                            format: { String(localized: "\($0) potjes") }
                        )
                    }
                }
                .padding(.horizontal, m.gutter * 1.5)
                .padding(.bottom, m.gutter * 2)
                .frame(maxWidth: m.overlayMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Gezinsrecords")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(entitlements: entitlements)
                .appMetrics()
        }
    }

    /// Eén record: de titel, de recordhouder(s) met hun bolletje en de
    /// waarde. Bij een gelijke stand staan ze er allebei — samen een record
    /// hebben is ook leuk.
    @ViewBuilder
    private func recordRow(
        title: String,
        icon: String,
        value: (PlayerProfile) -> Int,
        format: (Int) -> String,
        best: ([Int]) -> Int? = { $0.max() }
    ) -> some View {
        let record = best(contenders.map(value))
        let holders = contenders.filter { value($0) == record }

        // Een record van nul is nog geen record; die rij wacht stilletjes.
        if let record, record > 0 {
            HStack(spacing: m.gutter * 0.8) {
                Image(systemName: icon)
                    .font(.system(size: m.bodySize, weight: .black))
                    .foregroundStyle(AppTheme.coral)
                    .frame(width: m.bodySize * 1.6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.rounded(m.captionSize, .bold))
                        .foregroundStyle(AppTheme.cardSoft)
                    Text(format(record))
                        .font(AppTheme.rounded(m.bodySize + 2))
                        .foregroundStyle(AppTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: -m.avatarSize * 0.25) {
                    ForEach(holders) { holder in
                        AvatarBadge(profile: holder, size: m.avatarSize * 0.85)
                    }
                }
            }
            .padding(.horizontal, m.gutter)
            .padding(.vertical, m.gutter * 0.7)
            .toyBlock(fill: AppTheme.card, radius: m.cardCorner * 0.8, depth: 3, border: m.thinBorder + 0.5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(title): \(format(record)), \(holders.map(\.name).formatted(.list(type: .and)))"
            )
        }
    }

    private var lockedCard: some View {
        VStack(spacing: m.gutter) {
            Image(systemName: "lock.fill")
                .font(.system(size: m.titleSize * 0.6, weight: .black))
                .foregroundStyle(AppTheme.offInk)

            Text("De gezinsrecords horen bij de Gezinsversie.")
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.cardSoft)
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("Ontgrendel de Gezinsversie")
                    .font(AppTheme.rounded(m.buttonTextSize * 0.75))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: m.buttonHeight * 0.8)
            }
            .buttonStyle(ToyButtonStyle(
                fill: AppTheme.mint,
                radius: m.cardCorner * 0.9,
                depth: m.depth,
                border: m.border
            ))
        }
        .padding(m.gutter)
        .toyBlock(fill: AppTheme.card, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)
    }
}

#Preview {
    let profiles = ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json"))
    let _ = profiles.addProfile(name: "Lene")
    let _ = profiles.addProfile(name: "Ellis")

    NavigationStack {
        FamilyRecordsView()
    }
    .environment(profiles)
    .environment(EntitlementStore(previewUnlocked: true))
    .appMetrics()
}
