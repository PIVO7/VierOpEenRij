import Foundation

/// Eén afgerond potje in de geschiedenis van een profiel: genoeg voor het
/// grafiekje en de trofeeën, niet meer dan dat.
struct GameRecord: Codable, Equatable, Hashable {
    /// Eigen stenen op het bord bij winst; 0 bij een ander resultaat.
    var discs: Int
    var won: Bool
    var draw: Bool
    var date: Date
}
