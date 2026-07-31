import Foundation

/// De drie tegenstanders in code. Dommel gooit maar wat, Robbie pakt en
/// blokkeert winnende zetten, en Professor Punt rekent een paar beurten
/// vooruit met minimax.
struct ComputerAI {
    /// Middenkolommen zijn meer waard: daar lopen de meeste rijtjes doorheen.
    private static let centerWeights = [3, 4, 6, 8, 6, 4, 3]

    func chooseColumn(
        board: Board,
        player: Int,
        level: ComputerLevel,
        using rng: inout some RandomNumberGenerator
    ) -> Int {
        let available = board.availableColumns
        precondition(!available.isEmpty, "Geen zet mogelijk op een vol bord")

        switch level {
        case .easy:
            // Ziet een winnende zet de helft van de tijd; blokkeren doet hij
            // nooit — Dommel dommelt.
            if let win = winningColumn(board: board, player: player),
               Bool.random(using: &rng) {
                return win
            }
            return weightedRandom(from: available, using: &rng)

        case .medium:
            if let win = winningColumn(board: board, player: player) {
                return win
            }
            if let block = winningColumn(board: board, player: 1 - player) {
                return block
            }
            // Geen kolom kiezen waar de tegenstander er meteen bovenop wint,
            // tenzij het niet anders kan.
            let safe = available.filter { !givesOpponentWin(board: board, player: player, column: $0) }
            return weightedRandom(from: safe.isEmpty ? available : safe, using: &rng)

        case .hard:
            return minimaxColumn(board: board, player: player, using: &rng)
        }
    }

    /// De kolom waarmee deze speler meteen vier op een rij maakt, of `nil`.
    func winningColumn(board: Board, player: Int) -> Int? {
        for column in board.availableColumns {
            var copy = board
            if let cell = copy.drop(player: player, in: column),
               copy.winningLine(through: cell) != nil {
                return column
            }
        }
        return nil
    }

    /// Waar: na deze zet kan de tegenstander bovenop dezelfde kolom winnen.
    private func givesOpponentWin(board: Board, player: Int, column: Int) -> Bool {
        var copy = board
        guard copy.drop(player: player, in: column) != nil else { return true }
        guard copy.canDrop(in: column) else { return false }
        var reply = copy
        if let cell = reply.drop(player: 1 - player, in: column),
           reply.winningLine(through: cell) != nil {
            return true
        }
        return false
    }

    private func weightedRandom(from columns: [Int], using rng: inout some RandomNumberGenerator) -> Int {
        let weights = columns.map { Self.centerWeights[$0] }
        let total = weights.reduce(0, +)
        var pick = Int.random(in: 0..<max(total, 1), using: &rng)
        for (column, weight) in zip(columns, weights) {
            pick -= weight
            if pick < 0 { return column }
        }
        return columns[0]
    }

    // MARK: - Professor Punt

    /// Zo ver vooruit dat hij dubbele dreigingen opzet, maar kort genoeg om
    /// binnen een tel te beslissen.
    private static let searchDepth = 7

    private func minimaxColumn(board: Board, player: Int, using rng: inout some RandomNumberGenerator) -> Int {
        // Winnen en blokkeren eerst: dat scheelt zoekwerk en kan nooit fout.
        if let win = winningColumn(board: board, player: player) { return win }
        if let block = winningColumn(board: board, player: 1 - player) { return block }

        var bestColumns: [Int] = []
        var bestScore = Int.min
        for column in orderedColumns(board.availableColumns) {
            var copy = board
            copy.drop(player: player, in: column)
            let score = -negamax(
                board: copy,
                player: 1 - player,
                depth: Self.searchDepth - 1,
                alpha: Int.min + 1,
                beta: Int.max - 1
            )
            if score > bestScore {
                bestScore = score
                bestColumns = [column]
            } else if score == bestScore {
                bestColumns.append(column)
            }
        }
        // Gelijkwaardige zetten wisselen elkaar af, anders speelt de
        // professor elk potje identiek.
        return bestColumns.randomElement(using: &rng) ?? board.availableColumns[0]
    }

    /// Midden eerst zoeken: alfa-bèta snoeit dan het hardst.
    private func orderedColumns(_ columns: [Int]) -> [Int] {
        columns.sorted { abs($0 - 3) < abs($1 - 3) }
    }

    private func negamax(board: Board, player: Int, depth: Int, alpha: Int, beta: Int) -> Int {
        if board.isFull { return 0 }
        if depth == 0 { return evaluate(board: board, for: player) }

        var alpha = alpha
        var best = Int.min + 1
        for column in orderedColumns(board.availableColumns) {
            var copy = board
            guard let cell = copy.drop(player: player, in: column) else { continue }
            let score: Int
            if copy.winningLine(through: cell) != nil {
                // Sneller winnen is beter; de diepte houdt dat verschil vast.
                score = 100_000 + depth
            } else {
                score = -negamax(board: copy, player: 1 - player, depth: depth - 1, alpha: -beta, beta: -alpha)
            }
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    /// Telt alle vensters van vier: eigen kansen positief, die van de
    /// tegenstander negatief, en het midden een tikje extra.
    private func evaluate(board: Board, for player: Int) -> Int {
        var score = 0

        for row in 0..<Board.rows {
            if board[3, row] == player { score += 6 }
        }

        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for column in 0..<Board.columns {
            for row in 0..<Board.rows {
                for (dx, dy) in directions {
                    let endColumn = column + dx * (Board.winLength - 1)
                    let endRow = row + dy * (Board.winLength - 1)
                    guard (0..<Board.columns).contains(endColumn),
                          (0..<Board.rows).contains(endRow) else { continue }

                    var mine = 0
                    var theirs = 0
                    for step in 0..<Board.winLength {
                        let value = board[column + dx * step, row + dy * step]
                        if value == player {
                            mine += 1
                        } else if value != nil {
                            theirs += 1
                        }
                    }
                    score += Self.windowScore(mine: mine, theirs: theirs)
                }
            }
        }
        return score
    }

    private static func windowScore(mine: Int, theirs: Int) -> Int {
        if mine > 0, theirs > 0 { return 0 }
        switch (mine, theirs) {
        case (3, 0): return 60
        case (2, 0): return 12
        case (0, 3): return -70
        case (0, 2): return -12
        default: return 0
        }
    }
}
