import Foundation

/// Serialiseerbare snapshot van een lopend spel, zodat kids kunnen hervatten.
/// Het bord zelf staat er niet in: de zettenlijst is compacter en speelt bij
/// het laden gewoon opnieuw af.
struct GameSnapshot: Codable, Equatable {
    var mode: GameMode
    var players: [GamePlayer]
    var startingPlayerIndex: Int
    var moves: [Int]
    var turnMessage: String
    var savedAt: Date

    var currentPlayerIndex: Int {
        (startingPlayerIndex + moves.count) % max(players.count, 1)
    }

    /// Alleen een geldig, nog niet afgelopen spel is het hervatten waard.
    var isResumable: Bool {
        guard players.count == 2,
              (0..<players.count).contains(startingPlayerIndex),
              let board = Board.replaying(moves: moves, startingPlayer: startingPlayerIndex) else {
            return false
        }
        return board.winningLine() == nil && !board.isFull
    }

    var summaryTitle: String {
        let names = players.filter { !$0.isComputer }.map(\.name)
        switch mode {
        case .versusComputer:
            return names.first.map { String(localized: "\($0) vs Computer") } ?? mode.title
        case .versusFriends:
            return names.joined(separator: " · ")
        }
    }
}
