import Foundation

/// De drie tegenstanders in code. Dommel gooit maar wat, Robbie pakt en
/// blokkeert winnende zetten, en Professor Punt rekent een paar beurten
/// vooruit met minimax.
struct ComputerAI {
    /// Middenkolommen zijn meer waard: daar lopen de meeste rijtjes doorheen.
    private static let centerWeights = [3, 4, 6, 8, 6, 4, 3]

    /// De zet voor deze spelvorm. Klassiek is dat altijd een val; bij Pop-out
    /// weegt elke tegenstander ook het wegtrekken van een eigen steen mee —
    /// op zijn eigen niveau.
    func chooseMove(
        board: Board,
        player: Int,
        level: ComputerLevel,
        variant: GameVariant,
        using rng: inout some RandomNumberGenerator
    ) -> GameMove {
        guard variant == .popOut else {
            return .drop(chooseColumn(board: board, player: player, level: level, using: &rng))
        }
        let drops = board.availableColumns
        let pops = board.poppableColumns(for: player)
        precondition(!drops.isEmpty || !pops.isEmpty, "Geen zet mogelijk")

        switch level {
        case .easy:
            if let win = winningColumn(board: board, player: player), Bool.random(using: &rng) {
                return .drop(win)
            }
            // Dommel trekt af en toe zomaar een steen weg — ook als dat dom is.
            if let pop = pops.randomElement(using: &rng),
               drops.isEmpty || Int.random(in: 0..<4, using: &rng) == 0 {
                return .pop(pop)
            }
            return .drop(weightedRandom(from: drops, using: &rng))

        case .medium:
            if let win = winningColumn(board: board, player: player) { return .drop(win) }
            if let win = winningPop(board: board, player: player) { return .pop(win) }
            if let block = winningColumn(board: board, player: 1 - player) { return .drop(block) }
            let safeDrops = drops.filter { !givesOpponentWin(board: board, player: player, column: $0) }
            if !safeDrops.isEmpty { return .drop(weightedRandom(from: safeDrops, using: &rng)) }
            // Vallen kan niet meer of is overal gevaarlijk: dan een pop die de
            // ander niets geeft, en pas daarna wat er nog rest.
            let safePops = pops.filter { !popGivesOpponentWin(board: board, player: player, column: $0) }
            if let pop = safePops.randomElement(using: &rng) { return .pop(pop) }
            if !drops.isEmpty { return .drop(weightedRandom(from: drops, using: &rng)) }
            return .pop(pops[0])

        case .hard:
            return minimaxMove(board: board, player: player, variant: variant, using: &rng)
        }
    }

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
            return minimaxMove(board: board, player: player, variant: .classic, using: &rng).column
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

    /// De kolom waaruit een eigen steen trekken meteen vier oplevert, of
    /// `nil`. Krijgt de ander er ook vier van, dan wint toch de trekker.
    func winningPop(board: Board, player: Int) -> Int? {
        for column in board.poppableColumns(for: player) {
            var copy = board
            if copy.pop(player: player, from: column), copy.winningLine(for: player) != nil {
                return column
            }
        }
        return nil
    }

    /// Waar: deze pop geeft alleen de ander vier op een rij — zelfmoord.
    private func popGivesOpponentWin(board: Board, player: Int, column: Int) -> Bool {
        var copy = board
        guard copy.pop(player: player, from: column) else { return true }
        return copy.winningLine(for: player) == nil && copy.winningLine(for: 1 - player) != nil
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
    /// binnen een tel te beslissen. Bij Pop-out zijn er twee keer zoveel
    /// zetten per beurt, dus daar kijkt hij minder ver.
    private static func searchDepth(for variant: GameVariant) -> Int {
        variant == .popOut ? 5 : 7
    }

    private func minimaxMove(
        board: Board,
        player: Int,
        variant: GameVariant,
        using rng: inout some RandomNumberGenerator
    ) -> GameMove {
        // Winnen en blokkeren eerst: dat scheelt zoekwerk en kan nooit fout.
        if let win = winningColumn(board: board, player: player) { return .drop(win) }
        if variant == .popOut, let win = winningPop(board: board, player: player) { return .pop(win) }
        if let block = winningColumn(board: board, player: 1 - player) { return .drop(block) }

        let depth = Self.searchDepth(for: variant)
        var bestMoves: [GameMove] = []
        var bestScore = Int.min
        for move in legalMoves(board: board, player: player, variant: variant) {
            guard let (copy, outcome) = apply(move, to: board, player: player) else { continue }
            let score: Int
            switch outcome {
            case .win: score = 100_000 + depth
            case .loss: score = -(100_000 + depth)
            case .open:
                score = -negamax(
                    board: copy,
                    player: 1 - player,
                    depth: depth - 1,
                    alpha: Int.min + 1,
                    beta: Int.max - 1,
                    variant: variant
                )
            }
            if score > bestScore {
                bestScore = score
                bestMoves = [move]
            } else if score == bestScore {
                bestMoves.append(move)
            }
        }
        // Gelijkwaardige zetten wisselen elkaar af, anders speelt de
        // professor elk potje identiek.
        return bestMoves.randomElement(using: &rng)
            ?? board.availableColumns.first.map(GameMove.drop)
            ?? .pop(board.poppableColumns(for: player)[0])
    }

    /// Midden eerst zoeken: alfa-bèta snoeit dan het hardst.
    private func orderedColumns(_ columns: [Int]) -> [Int] {
        columns.sorted { abs($0 - 3) < abs($1 - 3) }
    }

    /// Alle zetten die nu kunnen: vallen, en bij Pop-out ook trekken.
    private func legalMoves(board: Board, player: Int, variant: GameVariant) -> [GameMove] {
        var moves = orderedColumns(board.availableColumns).map(GameMove.drop)
        if variant == .popOut {
            moves += board.poppableColumns(for: player).map(GameMove.pop)
        }
        return moves
    }

    private enum Outcome { case win, loss, open }

    /// Past een zet toe op een kopie en zegt meteen of hij het spel beslist.
    /// Een val kan alleen voor de zetter winnen; een pop kan ook de ander
    /// vier geven, en dan is het verlies — tenzij de zetter zelf ook vier
    /// heeft, want dan wint wie trok.
    private func apply(_ move: GameMove, to board: Board, player: Int) -> (Board, Outcome)? {
        var copy = board
        switch move {
        case .drop(let column):
            guard let cell = copy.drop(player: player, in: column) else { return nil }
            return (copy, copy.winningLine(through: cell) != nil ? .win : .open)
        case .pop(let column):
            guard copy.pop(player: player, from: column) else { return nil }
            if copy.winningLine(for: player) != nil { return (copy, .win) }
            if copy.winningLine(for: 1 - player) != nil { return (copy, .loss) }
            return (copy, .open)
        }
    }

    private func negamax(board: Board, player: Int, depth: Int, alpha: Int, beta: Int, variant: GameVariant) -> Int {
        let moves = legalMoves(board: board, player: player, variant: variant)
        if moves.isEmpty { return 0 }
        if depth == 0 { return evaluate(board: board, for: player) }

        var alpha = alpha
        var best = Int.min + 1
        for move in moves {
            guard let (copy, outcome) = apply(move, to: board, player: player) else { continue }
            let score: Int
            switch outcome {
            // Sneller winnen is beter; de diepte houdt dat verschil vast.
            case .win: score = 100_000 + depth
            case .loss: score = -(100_000 + depth)
            case .open:
                score = -negamax(board: copy, player: 1 - player, depth: depth - 1, alpha: -beta, beta: -alpha, variant: variant)
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
