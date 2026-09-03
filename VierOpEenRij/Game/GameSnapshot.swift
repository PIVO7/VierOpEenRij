import Foundation

/// Serialiseerbare snapshot van een lopend spel, zodat kids kunnen hervatten.
/// Het bord zelf staat er niet in: de zettenlijst is compacter en speelt bij
/// het laden gewoon opnieuw af.
struct GameSnapshot: Codable, Equatable {
    var mode: GameMode
    /// Optioneel: spellen die vóór de spelvormen bewaard zijn, zijn klassiek.
    var variant: GameVariant?
    var players: [GamePlayer]
    var startingPlayerIndex: Int
    /// Kolommen; bij Pop-out staat een pop erin als `-(kolom + 1)`.
    var moves: [Int]
    var turnMessage: String
    var savedAt: Date

    var currentPlayerIndex: Int {
        (startingPlayerIndex + moves.count) % max(players.count, 1)
    }

    /// Alleen een geldig, nog niet afgelopen spel is het hervatten waard.
    var isResumable: Bool {
        let popOut = (variant ?? .classic) == .popOut
        guard players.count == 2,
              (0..<players.count).contains(startingPlayerIndex),
              let board = Board.replaying(moves: moves, startingPlayer: startingPlayerIndex, allowingPops: popOut),
              board.winningLine() == nil else {
            return false
        }
        // Een vol bord is bij Pop-out nog geen einde zolang er te trekken valt.
        return !board.isFull || (popOut && !board.poppableColumns(for: currentPlayerIndex).isEmpty)
    }

    var summaryTitle: String {
        let names = players.filter { !$0.isComputer }.map(\.name)
        let base: String
        switch mode {
        case .versusComputer:
            base = names.first.map { String(localized: "\($0) vs Computer") } ?? mode.title
        case .versusFriends:
            base = names.joined(separator: " · ")
        }
        guard let variant, variant != .classic else { return base }
        return "\(base) · \(variant.title)"
    }
}
