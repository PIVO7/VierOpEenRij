import SwiftUI

/// Houdt het spel bij elkaar: bewaart de voortgang en vertaalt zetten naar
/// trillingen, banners en vieringen. Het tekenwerk zit in de losse views.
struct GameView: View {
    let engine: GameEngine
    /// Vervangt het spel door een vers potje met dezelfde deelnemers; de
    /// eigenaar van de cover wisselt de engine.
    let onRematch: () -> Void
    let onClose: () -> Void

    @Environment(ProfileStore.self) private var profileStore
    @Environment(GameStore.self) private var gameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.metrics) private var m

    @State private var didRecordResult = false
    @State private var isNewRecord = false
    @State private var showResult = false
    @State private var showExitConfirm = false
    @State private var resultReveal: Task<Void, Never>?
    @State private var dropPulse = 0
    @State private var turnPulse = 0
    @State private var winPulse = 0

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: m.gutter) {
                topBar

                // De tussenstand vlak boven het bord dat hij samenvat.
                // Alles hangt aan de bovenrand; de restruimte valt onderaan,
                // bij de hand, in plaats van als gat midden op het scherm.
                GameHeaderView(
                    players: engine.players,
                    currentPlayerID: engine.currentPlayer.id,
                    discIndex: engine.discIndex(for:)
                )

                statusLine

                BoardView(
                    board: engine.board,
                    winningCells: engine.winningCells,
                    discIndex: engine.discIndex(for:),
                    playerName: { engine.players[$0].name },
                    isEnabled: engine.canDrop,
                    onDrop: drop
                )

                undoRow

                Spacer(minLength: 0)
            }
            .padding(.horizontal, m.gutter)
            .padding(.vertical, m.gutter * 0.5)
            // De hele kolom op de bordbreedte, niet alleen het bord: anders
            // rekt de kop op een iPad uit over het volle scherm.
            .frame(maxWidth: m.contentMaxWidth)
            .frame(maxWidth: .infinity)

            if showResult {
                GameResultOverlay(
                    players: engine.players,
                    winnerProfileIDs: engine.winnerProfileIDs,
                    message: engine.turnMessage,
                    discCounts: engine.players.indices.map(engine.discCount(of:)),
                    isNewRecord: isNewRecord,
                    onRematch: onRematch,
                    onClose: onClose
                )
                .zIndex(4)
            }

            if showExitConfirm {
                ToyDialog(
                    title: String(localized: "Spel verlaten?"),
                    message: String(localized: "Je voortgang wordt bewaard."),
                    confirmTitle: String(localized: "Verlaten"),
                    cancelTitle: String(localized: "Doorspelen"),
                    onConfirm: leave,
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showExitConfirm = false
                        }
                    }
                )
                .zIndex(5)
            }
        }
        .task(id: engine.currentPlayerIndex) {
            await engine.playComputerTurnIfNeeded()
        }
        .onAppear {
            // Een hervat spel dat toch al uit bleek: meteen de eindstand.
            if engine.isFinished {
                showResult = true
            }
        }
        .onChange(of: engine.saveVersion) { _, _ in
            persistProgress()
        }
        .onChange(of: engine.moves.count) { oldCount, newCount in
            // Hier en niet op de knop: zo plopt het ook als de computer een
            // steen laat vallen. Bij een terugzet blijft het stil.
            guard newCount > oldCount else { return }
            dropPulse += 1
            SoundPlayer.shared.play(.drop)
        }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished else { return }
            gameDidFinish()
        }
        .onChange(of: engine.turnJustChanged) { _, changed in
            guard changed else { return }
            announceTurnChange()
            engine.acknowledgeTurnChange()
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.85), trigger: dropPulse)
        .sensoryFeedback(.selection, trigger: turnPulse)
        .sensoryFeedback(.success, trigger: winPulse)
    }

    // MARK: - Deelviews

    /// De staande spelstand onder de kop: wie er mag, of dat de computer
    /// nadenkt. Tijdens het eindscherm draagt de overlay de boodschap.
    private var statusLine: some View {
        Text(engine.turnMessage)
            .font(AppTheme.rounded(m.bodySize, .bold))
            .foregroundStyle(AppTheme.soft)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .opacity(showResult ? 0 : 1)
    }

    private var undoRow: some View {
        HStack {
            Button(action: undoLastMove) {
                Label("Zet terug", systemImage: "arrow.uturn.backward")
                    .font(AppTheme.rounded(m.captionSize + 1, .bold))
                    .foregroundStyle(engine.canUndo ? AppTheme.ink : AppTheme.offInk)
                    .padding(.horizontal, m.gutter)
                    .frame(minHeight: m.tapTarget)
            }
            .buttonStyle(ToyButtonStyle(
                fill: engine.canUndo ? AppTheme.card : AppTheme.offFill,
                radius: m.cellCorner + 1,
                depth: 3,
                border: m.thinBorder + 0.5
            ))
            .disabled(!engine.canUndo)

            Spacer()
        }
    }

    /// De dunne bovenrand: de steenteller (passieve meta-info) met de
    /// sluitknop ernaast. De tussenstand staat niet meer hier maar vlak
    /// boven het bord.
    private var topBar: some View {
        HStack(spacing: 8) {
            // Zelfde vertaalsleutel als voorheen; alleen de opmaak is
            // hoofdletters, in de stijl van de rondeteller in Dobbel.
            Text("Steen \(engine.moves.count + (engine.isFinished ? 0 : 1))")
                .textCase(.uppercase)
                .font(AppTheme.rounded(m.captionSize * 0.92))
                .kerning(1.6)
                .foregroundStyle(AppTheme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            Button(action: requestLeave) {
                Label("Spel verlaten", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: m.captionSize + 2, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: m.tapTarget, height: m.tapTarget)
            }
            .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: 3, border: m.thinBorder))
        }
    }

    // MARK: - Zetten

    private func drop(in column: Int) {
        engine.dropDisc(in: column)
    }

    private func undoLastMove() {
        engine.undoLastMove()
        turnPulse += 1
        SoundPlayer.shared.play(.score)
        AccessibilityNotification.Announcement(
            String(localized: "Zet teruggezet. \(engine.currentPlayer.name) is weer aan de beurt.")
        ).post()
    }

    /// Een afgelopen spel valt niets meer te bewaren, dus dan slaan we de
    /// bevestiging over.
    private func requestLeave() {
        if engine.isFinished {
            leave()
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                showExitConfirm = true
            }
        }
    }

    private func leave() {
        persistProgress()
        onClose()
    }

    // MARK: - Reacties op het spel

    /// Solo spreekt de aankondiging je aan; met z'n tweeën aan één toestel
    /// noemt ze de naam.
    private var turnAnnouncement: String {
        if engine.mode == .versusComputer, !engine.currentPlayer.isComputer {
            return String(localized: "Jij bent aan de beurt")
        }
        return String(localized: "\(engine.currentPlayer.name) is aan de beurt")
    }

    private func gameDidFinish() {
        winPulse += 1
        SoundPlayer.shared.play(.fanfare)
        recordResult()
        AccessibilityNotification.Announcement(engine.turnMessage).post()
        // De winnende rij eerst even laten zien; daarna pas de eindstand
        // eroverheen. Bewaard net als de bannertimer, zodat hij netjes
        // annuleerbaar is.
        resultReveal?.cancel()
        resultReveal = Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1400))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)) {
                showResult = true
            }
        }
    }

    private func recordResult() {
        guard !didRecordResult else { return }
        didRecordResult = true
        // Record checken vóór de statistieken worden bijgewerkt; de eerste
        // winst ooit telt niet als record.
        if engine.winnerProfileIDs.count == 1,
           let winnerIndex = engine.players.firstIndex(where: { engine.winnerProfileIDs.contains($0.profileID) }),
           let profile = profileStore.humanProfiles.first(where: { $0.id == engine.players[winnerIndex].profileID }),
           profile.fastestWin > 0,
           engine.discCount(of: winnerIndex) < profile.fastestWin {
            isNewRecord = true
        }
        gameStore.clear()
        let winnerDiscCount = engine.players.indices
            .first(where: { engine.winnerProfileIDs.contains(engine.players[$0].profileID) })
            .map(engine.discCount(of:)) ?? 0
        profileStore.recordGameResult(
            players: engine.players,
            winnerProfileIDs: engine.winnerProfileIDs,
            winnerDiscCount: winnerDiscCount
        )
    }

    /// Geen rood vlak meer bij een beurtwissel: de kop en de statusregel
    /// zeggen al wie er mag. De tik, het geluid en de VoiceOver-aankondiging
    /// markeren het moment.
    private func announceTurnChange() {
        guard !engine.isFinished else { return }
        turnPulse += 1
        SoundPlayer.shared.play(.turn)
        AccessibilityNotification.Announcement(turnAnnouncement).post()
    }

    private func persistProgress() {
        if engine.isFinished {
            gameStore.clear()
        } else {
            gameStore.save(engine.snapshot)
        }
    }
}

#Preview {
    let profiles = [
        PlayerProfile(name: "Lene", avatarColorIndex: 0),
        PlayerProfile(name: "Ellis", avatarColorIndex: 1)
    ]
    GameView(
        engine: GameEngine(mode: .versusFriends, profiles: profiles),
        onRematch: {},
        onClose: {}
    )
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json")))
    .environment(GameStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json")))
    .appMetrics()
}
