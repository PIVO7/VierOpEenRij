import XCTest
@testable import VierOpEenRij

final class ComputerAITests: XCTestCase {
    private let ai = ComputerAI()

    func testMediumTakesWinningMove() {
        var board = Board()
        board.drop(player: 1, in: 0)
        board.drop(player: 1, in: 1)
        board.drop(player: 1, in: 2)
        board.drop(player: 0, in: 0)
        var rng = SplitMix64(seed: 1)
        let column = ai.chooseColumn(board: board, player: 1, level: .medium, using: &rng)
        XCTAssertEqual(column, 3)
    }

    func testMediumBlocksOpponentWin() {
        var board = Board()
        board.drop(player: 0, in: 3)
        board.drop(player: 0, in: 4)
        board.drop(player: 0, in: 5)
        board.drop(player: 1, in: 0)
        var rng = SplitMix64(seed: 7)
        let column = ai.chooseColumn(board: board, player: 1, level: .medium, using: &rng)
        // Blokkeren kan links of rechts van het rijtje.
        XCTAssertTrue([2, 6].contains(column))
    }

    func testHardTakesWinningMove() {
        var board = Board()
        board.drop(player: 1, in: 2)
        board.drop(player: 1, in: 2)
        board.drop(player: 1, in: 2)
        board.drop(player: 0, in: 0)
        var rng = SplitMix64(seed: 3)
        let column = ai.chooseColumn(board: board, player: 1, level: .hard, using: &rng)
        XCTAssertEqual(column, 2)
    }

    func testHardBlocksOpponentVerticalThreat() {
        var board = Board()
        board.drop(player: 0, in: 5)
        board.drop(player: 0, in: 5)
        board.drop(player: 0, in: 5)
        board.drop(player: 1, in: 0)
        var rng = SplitMix64(seed: 3)
        let column = ai.chooseColumn(board: board, player: 1, level: .hard, using: &rng)
        XCTAssertEqual(column, 5)
    }

    func testEasyAlwaysPlaysLegalColumn() {
        var board = Board()
        // Kolom 0 vol maken zodat er een verboden kolom bestaat.
        for _ in 0..<3 {
            board.drop(player: 0, in: 0)
            board.drop(player: 1, in: 0)
        }
        var rng = SplitMix64(seed: 99)
        for _ in 0..<25 {
            let column = ai.chooseColumn(board: board, player: 0, level: .easy, using: &rng)
            XCTAssertTrue(board.canDrop(in: column))
        }
    }

    func testWinningColumnFinderSeesDiagonal() {
        var board = Board()
        board.drop(player: 0, in: 0)
        board.drop(player: 1, in: 1)
        board.drop(player: 0, in: 1)
        board.drop(player: 1, in: 2)
        board.drop(player: 0, in: 2)
        board.drop(player: 1, in: 3)
        board.drop(player: 0, in: 2)
        board.drop(player: 1, in: 3)
        board.drop(player: 1, in: 3)
        // Speler 0 wint door in kolom 3 bovenop te leggen (rij 3).
        XCTAssertEqual(ai.winningColumn(board: board, player: 0), 3)
    }
}
