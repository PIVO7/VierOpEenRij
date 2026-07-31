import XCTest
@testable import VierOpEenRij

final class BoardTests: XCTestCase {
    func testDropStacksFromBottom() {
        var board = Board()
        XCTAssertEqual(board.drop(player: 0, in: 3), Board.Cell(column: 3, row: 0))
        XCTAssertEqual(board.drop(player: 1, in: 3), Board.Cell(column: 3, row: 1))
        XCTAssertEqual(board[3, 0], 0)
        XCTAssertEqual(board[3, 1], 1)
        XCTAssertNil(board[3, 2])
    }

    func testFullColumnRejectsDrop() {
        var board = Board()
        for _ in 0..<Board.rows {
            XCTAssertNotNil(board.drop(player: 0, in: 0))
        }
        XCTAssertNil(board.drop(player: 1, in: 0))
        XCTAssertFalse(board.canDrop(in: 0))
        XCTAssertFalse(board.availableColumns.contains(0))
    }

    func testHorizontalWin() {
        var board = Board()
        for column in 0..<3 {
            board.drop(player: 0, in: column)
            board.drop(player: 1, in: column)
        }
        let cell = board.drop(player: 0, in: 3)!
        let line = board.winningLine(through: cell)
        XCTAssertEqual(line?.count, 4)
        XCTAssertEqual(line?.map(\.row), [0, 0, 0, 0])
    }

    func testVerticalWin() {
        var board = Board()
        for _ in 0..<3 {
            board.drop(player: 0, in: 2)
            board.drop(player: 1, in: 4)
        }
        let cell = board.drop(player: 0, in: 2)!
        XCTAssertEqual(board.winningLine(through: cell)?.count, 4)
    }

    func testDiagonalWin() {
        var board = Board()
        // Trap richting rechtsboven voor speler 0.
        board.drop(player: 0, in: 0)
        board.drop(player: 1, in: 1)
        board.drop(player: 0, in: 1)
        board.drop(player: 1, in: 2)
        board.drop(player: 0, in: 2)
        board.drop(player: 1, in: 3)
        board.drop(player: 0, in: 2)
        board.drop(player: 1, in: 3)
        board.drop(player: 0, in: 3)
        board.drop(player: 1, in: 5)
        let cell = board.drop(player: 0, in: 3)!
        let line = board.winningLine(through: cell)
        XCTAssertEqual(line?.count, 4)
        XCTAssertEqual(line, [
            Board.Cell(column: 0, row: 0),
            Board.Cell(column: 1, row: 1),
            Board.Cell(column: 2, row: 2),
            Board.Cell(column: 3, row: 3)
        ])
    }

    func testNoWinOnScatteredBoard() {
        var board = Board()
        board.drop(player: 0, in: 0)
        board.drop(player: 1, in: 1)
        board.drop(player: 0, in: 2)
        board.drop(player: 1, in: 3)
        XCTAssertNil(board.winningLine())
    }

    func testRemoveTopUndoesDrop() {
        var board = Board()
        board.drop(player: 0, in: 6)
        board.drop(player: 1, in: 6)
        board.removeTop(of: 6)
        XCTAssertEqual(board[6, 0], 0)
        XCTAssertNil(board[6, 1])
    }

    func testReplayRebuildsBoard() {
        let moves = [3, 3, 4, 2]
        let board = Board.replaying(moves: moves, startingPlayer: 0)
        XCTAssertEqual(board?[3, 0], 0)
        XCTAssertEqual(board?[3, 1], 1)
        XCTAssertEqual(board?[4, 0], 0)
        XCTAssertEqual(board?[2, 0], 1)
    }

    func testReplayRejectsInvalidMoves() {
        // Acht keer dezelfde kolom past niet in zes rijen.
        XCTAssertNil(Board.replaying(moves: Array(repeating: 0, count: 8), startingPlayer: 0))
    }
}
