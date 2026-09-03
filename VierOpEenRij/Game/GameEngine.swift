import Foundation
import Observation

@MainActor
@Observable
final class GameEngine {
    let mode: GameMode
    let variant: GameVariant
    private(set) var players: [GamePlayer]
    private(set) var board: Board
    let startingPlayerIndex: Int
    private(set) var currentPlayerIndex: Int
    /// De zettenlijst is de bron van waarheid: het bord volgt eruit, en de
    /// snapshot en de terugzetknop leunen erop.
    private(set) var moves: [Int] = []
    private(set) var lastDrop: Board.Cell?
    private(set) var isFinished = false
    private(set) var isDraw = false
    private(set) var winnerProfileIDs: [UUID] = []
    private(set) var winningCells: [Board.Cell] = []
    /// De computer "denkt na": kolommen zijn even niet aantikbaar.
    private(set) var isThinking = false
    private(set) var turnMessage: String = ""
    /// Bumps after meaningful state changes so de UI kan autosaven.
    private(set) var saveVersion = 0
    /// True kort nadat de beurt wisselde — UI toont de banner.
    private(set) var turnJustChanged = false
    /// Bumps bij een pop; de UI hangt er een eigen geluid aan.
    private(set) var popPulse = 0

    private var rng: SplitMix64
    private let computerAI: ComputerAI

    var currentPlayer: GamePlayer { players[currentPlayerIndex] }

    /// De kleurindex van een speler op het bord: wie begon speelt koraal,
    /// de ander amber — net als rood en geel op het echte spel.
    func discIndex(for playerIndex: Int) -> Int {
        playerIndex == startingPlayerIndex ? 0 : 1
    }

    var canDrop: Bool {
        !isFinished && !isThinking && !currentPlayer.isComputer
    }

    /// Pop-out: de kolommen waar de speler aan zet zijn eigen steen onderuit
    /// mag trekken. Leeg in de klassieke spelvorm en buiten zijn beurt.
    var poppableColumns: [Int] {
        guard variant == .popOut, canDrop else { return [] }
        return board.poppableColumns(for: currentPlayerIndex)
    }

    /// De vorige zet mag terug zolang het spel loopt en er een eigen zet te
    /// herroepen valt. Solo draait ook de tegenzet van de computer mee
    /// terug — en ook terwijl de computer nog nadenkt hoeft een kind niet te
    /// wachten: de denklus ziet na het terugzetten zelf dat hij klaar is.
    var canUndo: Bool {
        guard !isFinished, !currentPlayer.isComputer || isThinking else { return false }
        return moves.indices.contains { !players[playerIndex(forMove: $0)].isComputer }
    }

    /// Aantal stenen dat deze speler zelf al liet vallen; een pop telt niet.
    func discCount(of playerIndex: Int) -> Int {
        moves.indices.count(where: { self.playerIndex(forMove: $0) == playerIndex && moves[$0] >= 0 })
    }

    var snapshot: GameSnapshot {
        GameSnapshot(
            mode: mode,
            variant: variant,
            players: players,
            startingPlayerIndex: startingPlayerIndex,
            moves: moves,
            turnMessage: turnMessage,
            savedAt: .now
        )
    }

    init(
        mode: GameMode,
        variant: GameVariant = .classic,
        profiles: [PlayerProfile],
        startingPlayerIndex: Int = 0,
        seed: UInt64? = nil,
        computerAI: ComputerAI = ComputerAI()
    ) {
        self.mode = mode
        self.variant = variant
        self.players = profiles.map(GamePlayer.init)
        self.board = Board()
        self.startingPlayerIndex = min(max(startingPlayerIndex, 0), max(profiles.count - 1, 0))
        self.currentPlayerIndex = self.startingPlayerIndex
        self.computerAI = computerAI
        self.rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.turnMessage = String(localized: "\(currentPlayer.name) mag beginnen")
    }

    init(snapshot: GameSnapshot, seed: UInt64? = nil, computerAI: ComputerAI = ComputerAI()) {
        self.mode = snapshot.mode
        // Bewaarde spellen van vóór de spelvormen zijn klassiek.
        self.variant = snapshot.variant ?? .classic
        self.players = snapshot.players
        self.startingPlayerIndex = min(max(snapshot.startingPlayerIndex, 0), max(snapshot.players.count - 1, 0))
        self.moves = snapshot.moves
        self.board = Board.replaying(
            moves: snapshot.moves,
            startingPlayer: self.startingPlayerIndex,
            allowingPops: self.variant == .popOut
        ) ?? Board()
        self.currentPlayerIndex = (self.startingPlayerIndex + snapshot.moves.count) % max(snapshot.players.count, 1)
        self.computerAI = computerAI
        self.rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.turnMessage = snapshot.turnMessage

        lastDrop = Self.landingCell(ofLastMoveIn: moves, on: board)
        // Een bewaard spel dat toch al uit was, netjes afronden in plaats van
        // laten doorspelen.
        if !moves.isEmpty, let (winnerIndex, line) = winner(afterMoveBy: playerIndex(forMove: moves.count - 1)) {
            finishGame(winnerIndex: winnerIndex, line: line)
        } else if !hasLegalMove(for: currentPlayerIndex) {
            finishGame(winnerIndex: nil, line: [])
        }
    }

    /// Meldt of de steen echt gevallen is, zodat de UI geen geluid afvuurt
    /// bij een tik op een volle kolom.
    @discardableResult
    func dropDisc(in column: Int) -> Bool {
        guard canDrop else { return false }
        return applyDrop(in: column)
    }

    /// Pop-out: trekt de eigen steen onderuit een kolom. Meldt of het echt
    /// gebeurde — buiten de spelvorm of op andermans steen gebeurt er niets.
    @discardableResult
    func popDisc(from column: Int) -> Bool {
        guard variant == .popOut, canDrop else { return false }
        return applyPop(from: column)
    }

    func undoLastMove() {
        guard canUndo else { return }
        // Minstens één zet terug, en daarna verder tot er weer een mens aan
        // de beurt is: solo verdwijnt zo ook het antwoord van de computer.
        repeat {
            guard moves.popLast() != nil else { break }
        } while players[(startingPlayerIndex + moves.count) % players.count].isComputer && !moves.isEmpty

        // Opnieuw afspelen in plaats van de bovenste steen weghalen: na een
        // pop is de hele kolom verschoven en klopt "de bovenste" niet meer.
        board = Board.replaying(moves: moves, startingPlayer: startingPlayerIndex, allowingPops: variant == .popOut) ?? Board()
        currentPlayerIndex = (startingPlayerIndex + moves.count) % players.count
        lastDrop = Self.landingCell(ofLastMoveIn: moves, on: board)
        turnMessage = String(localized: "\(currentPlayer.name) is aan de beurt")
        markDirty()
    }

    func acknowledgeTurnChange() {
        turnJustChanged = false
    }

    func playComputerTurnIfNeeded() async {
        // Expliciet annuleerbaar: als het spel dichtgaat stopt de lus, in
        // plaats van in de achtergrond het potje uit te spelen.
        while !Task.isCancelled, !isFinished, currentPlayer.isComputer {
            isThinking = true
            turnMessage = String(localized: "\(currentPlayer.name) denkt na…")
            // Even "nadenken", ook al weet hij het meteen: een computer die
            // binnen een frame antwoordt voelt onklopbaar.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, !isFinished, currentPlayer.isComputer else {
                isThinking = false
                return
            }
            let move = computerAI.chooseMove(
                board: board,
                player: currentPlayerIndex,
                level: currentPlayer.computerLevel ?? .medium,
                variant: variant,
                using: &rng
            )
            isThinking = false
            switch move {
            case .drop(let column): applyDrop(in: column)
            case .pop(let column): applyPop(from: column)
            }
            // De steen even laten landen voor een eventuele volgende beurt.
            try? await Task.sleep(for: .milliseconds(Self.dropDuration))
        }
    }

    /// De deelnemers van dit spel als profielen, voor een rematch met
    /// dezelfde spelers en hetzelfde computerniveau.
    func rematchProfiles() -> [PlayerProfile] {
        players.map { player in
            PlayerProfile(
                id: player.profileID,
                name: player.name,
                avatarColorIndex: player.avatarColorIndex,
                avatarSymbol: player.avatarSymbol,
                computerLevel: player.computerLevel
            )
        }
    }

    /// Ruim genoeg voor de langste valanimatie in `BoardView` (val naar de
    /// onderste rij plus stuit).
    static let dropDuration = 700

    // MARK: - Privé

    @discardableResult
    private func applyDrop(in column: Int) -> Bool {
        guard let cell = board.drop(player: currentPlayerIndex, in: column) else { return false }
        moves.append(GameMove.drop(column).encoded)
        lastDrop = cell

        if let line = board.winningLine(through: cell) {
            finishGame(winnerIndex: currentPlayerIndex, line: line)
        } else if !hasLegalMove(for: (currentPlayerIndex + 1) % players.count) {
            finishGame(winnerIndex: nil, line: [])
        } else {
            advanceTurn()
        }
        markDirty()
        return true
    }

    @discardableResult
    private func applyPop(from column: Int) -> Bool {
        guard board.pop(player: currentPlayerIndex, from: column) else { return false }
        moves.append(GameMove.pop(column).encoded)
        // De hele kolom schoof; geen enkele steen is "net geland".
        lastDrop = nil
        popPulse += 1

        if let (winnerIndex, line) = winner(afterMoveBy: currentPlayerIndex) {
            finishGame(winnerIndex: winnerIndex, line: line)
        } else if !hasLegalMove(for: (currentPlayerIndex + 1) % players.count) {
            finishGame(winnerIndex: nil, line: [])
        } else {
            advanceTurn()
        }
        markDirty()
        return true
    }

    /// Wie er na deze zet vier op een rij heeft. Na een pop kunnen dat beide
    /// kleuren tegelijk zijn; dan wint wie de zet deed — het was zijn keuze.
    /// Alleen de ander vier? Dan heeft de trekker zichzelf verslagen.
    private func winner(afterMoveBy mover: Int) -> (Int, [Board.Cell])? {
        if let line = board.winningLine(for: mover) { return (mover, line) }
        let other = (mover + 1) % players.count
        if let line = board.winningLine(for: other) { return (other, line) }
        return nil
    }

    /// Klassiek is een vol bord het einde; bij Pop-out kan wie nog een eigen
    /// steen onderin heeft gewoon verder.
    private func hasLegalMove(for player: Int) -> Bool {
        !board.isFull || (variant == .popOut && !board.poppableColumns(for: player).isEmpty)
    }

    /// Het vakje waar de laatste steen landde, voor de highlight. Na een pop
    /// is er geen.
    private static func landingCell(ofLastMoveIn moves: [Int], on board: Board) -> Board.Cell? {
        guard let last = moves.last, case .drop(let column) = GameMove(encoded: last) else { return nil }
        return Board.Cell(column: column, row: max(board.height(of: column) - 1, 0))
    }

    private func advanceTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        turnMessage = String(localized: "\(currentPlayer.name) is aan de beurt")
        turnJustChanged = true
    }

    private func finishGame(winnerIndex: Int?, line: [Board.Cell]) {
        isFinished = true
        winningCells = line
        if let winnerIndex {
            let winner = players[winnerIndex]
            winnerProfileIDs = [winner.profileID]
            isDraw = false
            let count = discCount(of: winnerIndex)
            turnMessage = String(localized: "\(winner.name) wint na \(count) stenen!")
        } else {
            winnerProfileIDs = []
            isDraw = true
            turnMessage = String(localized: "Gelijkspel — het bord is vol!")
        }
    }

    private func playerIndex(forMove index: Int) -> Int {
        (startingPlayerIndex + index) % players.count
    }

    private func markDirty() {
        saveVersion += 1
    }
}
