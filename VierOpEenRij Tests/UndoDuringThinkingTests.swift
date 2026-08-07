import XCTest
@testable import VierOpEenRij

/// De terugzetknop terwijl de computer "nadenkt": een kind hoeft niet te
/// wachten tot de denkpauze voorbij is om zijn eigen zet terug te nemen.
@MainActor
final class UndoDuringThinkingTests: XCTestCase {
    private func makeEngine() -> GameEngine {
        GameEngine(
            mode: .versusComputer,
            profiles: [
                PlayerProfile(name: "Lene"),
                .computer(level: .medium)
            ],
            seed: 7
        )
    }

    func testNoUndoBeforeAnyHumanMove() {
        XCTAssertFalse(makeEngine().canUndo)
    }

    func testUndoWhileComputerIsThinking() async {
        let engine = makeEngine()
        engine.dropDisc(in: 3)

        // De denklus start en blijft ruim 700 ms "nadenken" — tijd genoeg
        // om er middenin te prikken.
        let thinkTask = Task { await engine.playComputerTurnIfNeeded() }
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(engine.isThinking)
        XCTAssertTrue(engine.canUndo, "Tijdens het denken moet terugzetten kunnen")

        engine.undoLastMove()
        XCTAssertEqual(engine.moves, [], "De eigen zet is weer van het bord")
        XCTAssertFalse(engine.currentPlayer.isComputer, "De mens is weer aan de beurt")

        // De denklus ziet zelf dat er niets meer te doen valt.
        thinkTask.cancel()
        await thinkTask.value
        XCTAssertFalse(engine.isThinking)
        XCTAssertFalse(engine.isFinished)
    }

    func testUndoRemovesComputerReplyToo() async {
        let engine = makeEngine()
        engine.dropDisc(in: 3)
        // Laat de computer echt antwoorden.
        await engine.playComputerTurnIfNeeded()
        XCTAssertEqual(engine.moves.count, 2)

        engine.undoLastMove()
        XCTAssertEqual(engine.moves, [], "Solo verdwijnt ook het antwoord van de computer")
        XCTAssertFalse(engine.currentPlayer.isComputer)
    }
}
