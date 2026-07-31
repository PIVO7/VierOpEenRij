import Foundation

/// Het speelbord: 7 kolommen van 6 vakjes. Rij 0 is de onderste rij, zodat
/// een steen "valt" naar de laagste vrije rij. Elke cel houdt de spelerindex
/// vast (0 of 1), of `nil` zolang hij leeg is.
struct Board: Equatable, Codable {
    static let columns = 7
    static let rows = 6
    static let winLength = 4

    struct Cell: Equatable, Hashable, Codable {
        let column: Int
        let row: Int
    }

    /// Kolom-per-kolom, van onder naar boven: `grid[kolom][rij]`.
    private(set) var grid: [[Int?]]

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.rows), count: Self.columns)
    }

    subscript(column: Int, row: Int) -> Int? {
        guard (0..<Self.columns).contains(column), (0..<Self.rows).contains(row) else { return nil }
        return grid[column][row]
    }

    /// Hoeveel stenen er al in een kolom liggen; meteen ook de rij waar de
    /// volgende steen landt.
    func height(of column: Int) -> Int {
        grid[column].firstIndex(where: { $0 == nil }) ?? Self.rows
    }

    func canDrop(in column: Int) -> Bool {
        (0..<Self.columns).contains(column) && height(of: column) < Self.rows
    }

    var availableColumns: [Int] {
        (0..<Self.columns).filter(canDrop(in:))
    }

    var isFull: Bool {
        availableColumns.isEmpty
    }

    /// Laat een steen vallen en meldt waar hij landde, of `nil` als de kolom
    /// vol is.
    @discardableResult
    mutating func drop(player: Int, in column: Int) -> Cell? {
        guard canDrop(in: column) else { return nil }
        let row = height(of: column)
        grid[column][row] = player
        return Cell(column: column, row: row)
    }

    /// Haalt de bovenste steen uit een kolom weer weg, voor de terugzetknop.
    mutating func removeTop(of column: Int) {
        let filled = height(of: column)
        guard filled > 0 else { return }
        grid[column][filled - 1] = nil
    }

    /// De vier windrichtingen die een rij kunnen vormen; de tegenrichting
    /// wordt bij het zoeken meegenomen.
    private static let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

    /// De winnende vier (of meer) op een rij door deze cel, of `nil`.
    func winningLine(through cell: Cell) -> [Cell]? {
        guard let player = self[cell.column, cell.row] else { return nil }

        for (dx, dy) in Self.directions {
            var line = [cell]
            for sign in [1, -1] {
                var column = cell.column + dx * sign
                var row = cell.row + dy * sign
                while self[column, row] == player {
                    line.append(Cell(column: column, row: row))
                    column += dx * sign
                    row += dy * sign
                }
            }
            if line.count >= Self.winLength {
                return line.sorted { ($0.column, $0.row) < ($1.column, $1.row) }
            }
        }
        return nil
    }

    /// Zoekt over het hele bord, voor een hervat spel waarvan alleen de
    /// zetten bewaard zijn.
    func winningLine() -> [Cell]? {
        for column in 0..<Self.columns {
            for row in 0..<height(of: column) {
                if let line = winningLine(through: Cell(column: column, row: row)) {
                    return line
                }
            }
        }
        return nil
    }

    /// Bouwt het bord opnieuw op uit een zettenlijst. Ongeldige zetten (volle
    /// of onbestaande kolom) leveren `nil`: dat bewaarde spel is corrupt.
    static func replaying(moves: [Int], startingPlayer: Int) -> Board? {
        var board = Board()
        for (index, column) in moves.enumerated() {
            let player = (startingPlayer + index) % 2
            guard board.drop(player: player, in: column) != nil else { return nil }
        }
        return board
    }
}
