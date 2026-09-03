import Foundation

/// Eén zet: een steen laten vallen, of (Pop-out) een eigen steen onderuit
/// een kolom trekken.
enum GameMove: Equatable {
    case drop(Int)
    case pop(Int)

    var column: Int {
        switch self {
        case .drop(let column), .pop(let column): column
        }
    }

    var isPop: Bool {
        if case .pop = self { return true }
        return false
    }

    /// De zettenlijst blijft een rij getallen: een pop is `-(kolom + 1)`,
    /// zodat bewaarde spellen van vóór de spelvormen (alleen kolommen)
    /// gewoon blijven laden.
    var encoded: Int {
        switch self {
        case .drop(let column): column
        case .pop(let column): -(column + 1)
        }
    }

    init(encoded: Int) {
        self = encoded < 0 ? .pop(-encoded - 1) : .drop(encoded)
    }
}
