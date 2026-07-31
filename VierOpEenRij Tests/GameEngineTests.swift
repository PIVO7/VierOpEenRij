import XCTest
@testable import VierOpEenRij

@MainActor
final class GameEngineTests: XCTestCase {
    private func friendsEngine() -> GameEngine {
        GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            seed: 42
        )
    }

    func testDropAdvancesTurn() {
        let engine = friendsEngine()
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertTrue(engine.dropDisc(in: 3))
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertEqual(engine.board[3, 0], 0)
        XCTAssertTrue(engine.turnJustChanged)
    }

    func testDropInFullColumnFails() {
        let engine = friendsEngine()
        for _ in 0..<Board.rows {
            XCTAssertTrue(engine.dropDisc(in: 0))
        }
        XCTAssertFalse(engine.dropDisc(in: 0))
    }

    func testWinFinishesGame() {
        let engine = friendsEngine()
        // Speler 0 bouwt kolom 2, speler 1 legt ernaast.
        for _ in 0..<3 {
            engine.dropDisc(in: 2)
            engine.dropDisc(in: 5)
        }
        engine.dropDisc(in: 2)
        XCTAssertTrue(engine.isFinished)
        XCTAssertFalse(engine.isDraw)
        XCTAssertEqual(engine.winnerProfileIDs, [engine.players[0].profileID])
        XCTAssertEqual(engine.winningCells.count, 4)
        XCTAssertTrue(engine.turnMessage.contains("Lene"))
        XCTAssertTrue(engine.turnMessage.contains("4"))
        XCTAssertFalse(engine.canDrop)
    }

    func testUndoRemovesOneMoveVersusFriends() {
        let engine = friendsEngine()
        engine.dropDisc(in: 3)
        engine.dropDisc(in: 4)
        XCTAssertTrue(engine.canUndo)
        engine.undoLastMove()
        XCTAssertEqual(engine.moves, [3])
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertNil(engine.board[4, 0])
    }

    func testUndoUnavailableWithoutMoves() {
        let engine = friendsEngine()
        XCTAssertFalse(engine.canUndo)
        engine.undoLastMove()
        XCTAssertTrue(engine.moves.isEmpty)
    }

    func testUndoVersusComputerRemovesReplyToo() async {
        let engine = GameEngine(
            mode: .versusComputer,
            profiles: [
                PlayerProfile(name: "Lene"),
                .computer(level: .medium)
            ],
            seed: 42
        )
        engine.dropDisc(in: 3)
        await engine.playComputerTurnIfNeeded()
        XCTAssertEqual(engine.moves.count, 2)
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertTrue(engine.canUndo)
        engine.undoLastMove()
        XCTAssertTrue(engine.moves.isEmpty)
        XCTAssertEqual(engine.currentPlayerIndex, 0)
    }

    func testSnapshotRoundTrip() {
        let engine = friendsEngine()
        engine.dropDisc(in: 3)
        engine.dropDisc(in: 4)
        engine.dropDisc(in: 3)

        let restored = GameEngine(snapshot: engine.snapshot, seed: 1)
        XCTAssertEqual(restored.moves, [3, 4, 3])
        XCTAssertEqual(restored.currentPlayerIndex, 1)
        XCTAssertEqual(restored.board, engine.board)
        XCTAssertFalse(restored.isFinished)
    }

    func testFinishedSnapshotFinishesOnRestore() {
        let engine = friendsEngine()
        for _ in 0..<3 {
            engine.dropDisc(in: 2)
            engine.dropDisc(in: 5)
        }
        engine.dropDisc(in: 2)

        let restored = GameEngine(snapshot: engine.snapshot, seed: 1)
        XCTAssertTrue(restored.isFinished)
        XCTAssertEqual(restored.winnerProfileIDs, [engine.players[0].profileID])
        XCTAssertEqual(restored.winningCells.count, 4)
    }

    func testDiscIndexFollowsStartingPlayer() {
        let profiles = [
            PlayerProfile(name: "Lene"),
            PlayerProfile(name: "Ellis", avatarColorIndex: 1)
        ]
        let second = GameEngine(mode: .versusFriends, profiles: profiles, startingPlayerIndex: 1, seed: 1)
        XCTAssertEqual(second.currentPlayerIndex, 1)
        // De beginner speelt altijd koraal (schijfkleur 0).
        XCTAssertEqual(second.discIndex(for: 1), 0)
        XCTAssertEqual(second.discIndex(for: 0), 1)
    }

    func testDiscCountPerPlayer() {
        let engine = friendsEngine()
        engine.dropDisc(in: 0)
        engine.dropDisc(in: 1)
        engine.dropDisc(in: 2)
        XCTAssertEqual(engine.discCount(of: 0), 2)
        XCTAssertEqual(engine.discCount(of: 1), 1)
    }
}
