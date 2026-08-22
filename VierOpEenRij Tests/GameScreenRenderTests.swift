import XCTest
import SwiftUI
@testable import VierOpEenRij

/// Rendert het volledige spelscherm naar PNG, zodat een indeling zonder
/// simulator te beoordelen valt. Slaat over zonder RENDER_OUTPUT_DIR.
@MainActor
final class GameScreenRenderTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderGameScreen() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }

        let engine = GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene", avatarColorIndex: 4, avatarSymbol: "heart.fill"),
                PlayerProfile(name: "Papa", avatarColorIndex: 1, avatarSymbol: "star.fill")
            ],
            seed: 7
        )
        for column in [3, 3, 4, 2, 5, 4, 2, 1, 3] {
            engine.dropDisc(in: column)
        }

        let view = GameView(engine: engine, onRematch: {}, onClose: {})
            .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "render-\(UUID()).json")))
            .environment(GameStore(fileURL: URL.temporaryDirectory.appending(path: "render-\(UUID()).json")))
            .environment(\.metrics, .phone)
            .frame(width: 393, height: 852)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        try XCTUnwrap(image.pngData())
            .write(to: outputDirectory.appending(path: "spelscherm.png"))
    }
}
