import Foundation
import Observation

@MainActor
@Observable
final class GameEngine {
    let mode: GameMode
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

    /// De vorige zet mag terug zolang het spel loopt en er een eigen zet te
    /// herroepen valt. Solo draait ook de tegenzet van de computer mee terug.
    var canUndo: Bool {
        guard canDrop else { return false }
        return moves.indices.contains { !players[playerIndex(forMove: $0)].isComputer }
    }

    /// Aantal stenen dat deze speler zelf al legde.
    func discCount(of playerIndex: Int) -> Int {
        moves.indices.filter { self.playerIndex(forMove: $0) == playerIndex }.count
    }

    var snapshot: GameSnapshot {
        GameSnapshot(
            mode: mode,
            players: players,
            startingPlayerIndex: startingPlayerIndex,
            moves: moves,
            turnMessage: turnMessage,
            savedAt: .now
        )
    }

    init(
        mode: GameMode,
        profiles: [PlayerProfile],
        startingPlayerIndex: Int = 0,
        seed: UInt64? = nil,
        computerAI: ComputerAI = ComputerAI()
    ) {
        self.mode = mode
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
        self.players = snapshot.players
        self.startingPlayerIndex = min(max(snapshot.startingPlayerIndex, 0), max(snapshot.players.count - 1, 0))
        self.moves = snapshot.moves
        self.board = Board.replaying(moves: snapshot.moves, startingPlayer: self.startingPlayerIndex) ?? Board()
        self.currentPlayerIndex = (self.startingPlayerIndex + snapshot.moves.count) % max(snapshot.players.count, 1)
        self.computerAI = computerAI
        self.rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.turnMessage = snapshot.turnMessage

        if let column = moves.last {
            let row = board.height(of: column) - 1
            lastDrop = Board.Cell(column: column, row: max(row, 0))
        }
        // Een bewaard spel dat toch al uit was, netjes afronden in plaats van
        // laten doorspelen.
        if let line = board.winningLine() {
            let winnerIndex = (startingPlayerIndex + moves.count - 1) % players.count
            finishGame(winnerIndex: winnerIndex, line: line)
        } else if board.isFull {
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

    func undoLastMove() {
        guard canUndo else { return }
        // Minstens één zet terug, en daarna verder tot er weer een mens aan
        // de beurt is: solo verdwijnt zo ook het antwoord van de computer.
        repeat {
            guard let column = moves.popLast() else { break }
            board.removeTop(of: column)
        } while players[(startingPlayerIndex + moves.count) % players.count].isComputer && !moves.isEmpty

        currentPlayerIndex = (startingPlayerIndex + moves.count) % players.count
        if let column = moves.last {
            let row = board.height(of: column) - 1
            lastDrop = Board.Cell(column: column, row: max(row, 0))
        } else {
            lastDrop = nil
        }
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
            let column = computerAI.chooseColumn(
                board: board,
                player: currentPlayerIndex,
                level: currentPlayer.computerLevel ?? .medium,
                using: &rng
            )
            isThinking = false
            applyDrop(in: column)
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

    /// Even lang als de valanimatie van een steen in `BoardView`.
    static let dropDuration = 420

    // MARK: - Privé

    @discardableResult
    private func applyDrop(in column: Int) -> Bool {
        guard let cell = board.drop(player: currentPlayerIndex, in: column) else { return false }
        moves.append(column)
        lastDrop = cell

        if let line = board.winningLine(through: cell) {
            finishGame(winnerIndex: currentPlayerIndex, line: line)
        } else if board.isFull {
            finishGame(winnerIndex: nil, line: [])
        } else {
            advanceTurn()
        }
        markDirty()
        return true
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
