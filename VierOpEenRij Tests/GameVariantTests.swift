import XCTest
@testable import VierOpEenRij

/// De spelvorm Pop-out: een eigen steen onderuit een kolom trekken, waarna
/// alles erboven zakt — en soms ineens de ander vier op een rij heeft.
@MainActor
final class GameVariantTests: XCTestCase {
    private func makeEngine(variant: GameVariant = .popOut) -> GameEngine {
        GameEngine(
            mode: .versusFriends,
            variant: variant,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            seed: 42
        )
    }

    /// Speelt een rij kolommen af, om de beurt, en controleert dat elke
    /// steen echt viel.
    private func play(_ columns: [Int], on engine: GameEngine) {
        for column in columns {
            XCTAssertTrue(engine.dropDisc(in: column), "Kolom \(column) hoort vrij te zijn")
        }
        XCTAssertFalse(engine.isFinished, "De opbouw mag het spel nog niet beslissen")
    }

    /// Lene (0) heeft na een pop van kolom 0 een liggende rij op rij 1; Ellis
    /// heeft nergens vier. Lene aan zet.
    private static let leneWinsByPop = [0, 0, 0, 1, 1, 2, 2, 5, 3, 6, 3, 5]

    /// Zelfde idee, andersom: als Lene kolom 0 trekt, zakt Ellis' rij op zijn
    /// plek en heeft alleen Ellis vier. Lene aan zet.
    private static let leneLosesByPop = [0, 2, 0, 2, 1, 0, 5, 1, 6, 3, 5, 3]

    // MARK: - Bord

    func testPopRemovesTheBottomDiscAndLowersTheRest() {
        var board = Board()
        board.drop(player: 0, in: 3)
        board.drop(player: 1, in: 3)
        board.drop(player: 0, in: 3)

        XCTAssertTrue(board.canPop(player: 0, from: 3))
        XCTAssertFalse(board.canPop(player: 1, from: 3))
        XCTAssertFalse(board.canPop(player: 0, from: 4))
        XCTAssertTrue(board.pop(player: 0, from: 3))

        XCTAssertEqual(board[3, 0], 1)
        XCTAssertEqual(board[3, 1], 0)
        XCTAssertNil(board[3, 2])
        XCTAssertEqual(board.height(of: 3), 2)
    }

    func testMoveEncodingRoundTrips() {
        for column in 0..<Board.columns {
            XCTAssertEqual(GameMove(encoded: GameMove.drop(column).encoded), .drop(column))
            XCTAssertEqual(GameMove(encoded: GameMove.pop(column).encoded), .pop(column))
        }
        XCTAssertEqual(GameMove.pop(0).encoded, -1)
    }

    // MARK: - Engine

    func testClassicNeverPops() {
        let engine = makeEngine(variant: .classic)
        play([3, 4], on: engine)

        XCTAssertTrue(engine.poppableColumns.isEmpty)
        XCTAssertFalse(engine.popDisc(from: 3))
        XCTAssertEqual(engine.moves, [3, 4])
    }

    func testOnlyYourOwnBottomDiscCanBePopped() {
        let engine = makeEngine()
        play([3, 3], on: engine)
        // Lene aan zet: onderin kolom 3 ligt haar steen.
        XCTAssertEqual(engine.poppableColumns, [3])

        play([0], on: engine)
        // Ellis aan zet: onderin 0 en 3 ligt Lene, dus niets te trekken.
        XCTAssertTrue(engine.poppableColumns.isEmpty)
        XCTAssertFalse(engine.popDisc(from: 3))
    }

    func testPopThatCompletesYourOwnFourWins() {
        let engine = makeEngine()
        play(Self.leneWinsByPop, on: engine)
        XCTAssertEqual(engine.currentPlayerIndex, 0)

        XCTAssertTrue(engine.popDisc(from: 0))

        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.winnerProfileIDs, [engine.players[0].profileID])
        XCTAssertEqual(engine.winningCells.count, 4)
        XCTAssertTrue(engine.winningCells.allSatisfy { $0.row == 1 })
        XCTAssertEqual(engine.popPulse, 1)
    }

    /// De valkuil van Pop-out: door het zakken krijgt de ánder vier.
    func testPopThatHandsTheOpponentFourLosesTheGame() {
        let engine = makeEngine()
        play(Self.leneLosesByPop, on: engine)
        XCTAssertEqual(engine.currentPlayerIndex, 0)

        XCTAssertTrue(engine.popDisc(from: 0))

        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.winnerProfileIDs, [engine.players[1].profileID])
        XCTAssertTrue(engine.turnMessage.contains("Ellis"))
    }

    func testUndoAfterAPopRestoresTheColumn() {
        let engine = makeEngine()
        play([3, 4, 3], on: engine)
        // Ellis trekt zijn steen uit kolom 4: die kolom is weer leeg.
        XCTAssertTrue(engine.popDisc(from: 4))
        XCTAssertNil(engine.board[4, 0])
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertNil(engine.lastDrop)

        engine.undoLastMove()

        XCTAssertEqual(engine.moves, [3, 4, 3])
        XCTAssertEqual(engine.board[4, 0], 1)
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertEqual(engine.lastDrop, Board.Cell(column: 3, row: 1))
    }

    func testDiscCountIgnoresPops() {
        let engine = makeEngine()
        play([3, 4, 3], on: engine)
        XCTAssertTrue(engine.popDisc(from: 4))

        XCTAssertEqual(engine.discCount(of: 0), 2)
        XCTAssertEqual(engine.discCount(of: 1), 1)
    }

    // MARK: - Bewaren

    func testSnapshotWithPopsRoundTrips() {
        let engine = makeEngine()
        play([3, 4, 3], on: engine)
        XCTAssertTrue(engine.popDisc(from: 4))

        let snapshot = engine.snapshot
        XCTAssertEqual(snapshot.variant, .popOut)
        XCTAssertEqual(snapshot.moves, [3, 4, 3, -5])
        XCTAssertTrue(snapshot.isResumable)
        XCTAssertTrue(snapshot.summaryTitle.contains(GameVariant.popOut.title))

        let restored = GameEngine(snapshot: snapshot, seed: 1)
        XCTAssertEqual(restored.variant, .popOut)
        XCTAssertEqual(restored.board, engine.board)
        XCTAssertEqual(restored.currentPlayerIndex, 0)
        XCTAssertFalse(restored.isFinished)
    }

    /// Een pop in een klassiek spel kan alleen een corrupt bestand zijn; en
    /// bewaarde spellen van vóór de spelvormen laden als klassiek.
    func testClassicSnapshotRejectsPops() {
        var snapshot = makeEngine(variant: .classic).snapshot
        XCTAssertEqual(GameEngine(snapshot: snapshot).variant, .classic)
        snapshot.variant = nil
        XCTAssertEqual(GameEngine(snapshot: snapshot).variant, .classic)

        snapshot.moves = [3, -4]
        XCTAssertFalse(snapshot.isResumable)
    }

    // MARK: - Computer

    func testMediumTakesAWinningPop() {
        let engine = makeEngine()
        play(Self.leneWinsByPop, on: engine)
        var rng = SplitMix64(seed: 3)

        let move = ComputerAI().chooseMove(board: engine.board, player: 0, level: .medium, variant: .popOut, using: &rng)

        XCTAssertEqual(move, .pop(0))
    }

    func testMediumNeverPopsIntoTheOpponentsFour() {
        let engine = makeEngine()
        play(Self.leneLosesByPop, on: engine)
        let ai = ComputerAI()

        for seed in 1...12 {
            var rng = SplitMix64(seed: UInt64(seed))
            let move = ai.chooseMove(board: engine.board, player: 0, level: .medium, variant: .popOut, using: &rng)
            XCTAssertNotEqual(move, .pop(0), "Kolom 0 trekken geeft Ellis vier op een rij")
        }
    }

    func testHardTakesAWinningPopAndStaysLegal() {
        let engine = makeEngine()
        play(Self.leneWinsByPop, on: engine)
        var rng = SplitMix64(seed: 5)
        let ai = ComputerAI()

        XCTAssertEqual(ai.chooseMove(board: engine.board, player: 0, level: .hard, variant: .popOut, using: &rng), .pop(0))

        // En zonder directe winst blijft elke zet legaal.
        let fresh = makeEngine()
        play([3, 3, 4], on: fresh)
        let move = ai.chooseMove(board: fresh.board, player: 1, level: .hard, variant: .popOut, using: &rng)
        switch move {
        case .drop(let column): XCTAssertTrue(fresh.board.canDrop(in: column))
        case .pop(let column): XCTAssertTrue(fresh.board.canPop(player: 1, from: column))
        }
    }

    /// Klassiek verandert er niets aan de computer: hij laat altijd vallen.
    func testClassicComputerOnlyDrops() {
        var board = Board()
        board.drop(player: 1, in: 3)
        board.drop(player: 0, in: 4)
        var rng = SplitMix64(seed: 9)
        for level in ComputerLevel.allCases {
            let move = ComputerAI().chooseMove(board: board, player: 1, level: level, variant: .classic, using: &rng)
            XCTAssertFalse(move.isPop)
        }
    }
}
