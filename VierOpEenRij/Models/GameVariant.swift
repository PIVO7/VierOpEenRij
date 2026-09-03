import Foundation

/// De spelvorm. Klassiek laat je stenen vallen tot er vier liggen; bij
/// Pop-out mag je in plaats daarvan een eigen steen onderuit een kolom
/// trekken, waarna alles erboven een vakje zakt. Dat maakt het bord nooit
/// "af": een dichtgemetselde stelling kan met één trek weer openbreken —
/// voor jou, of voor de ander.
enum GameVariant: String, CaseIterable, Identifiable, Codable {
    case classic
    case popOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: String(localized: "Klassiek")
        case .popOut: String(localized: "Pop-out")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: String(localized: "Laat vallen tot er vier liggen")
        case .popOut: String(localized: "Trek ook stenen onderuit")
        }
    }

    var symbol: String {
        switch self {
        case .classic: "arrow.down.to.line"
        case .popOut: "arrow.up.and.down"
        }
    }

    /// Alleen de klassieke spelvorm is gratis; de rest hoort bij de
    /// Gezinsversie.
    var isPremium: Bool { self != .classic }
}
