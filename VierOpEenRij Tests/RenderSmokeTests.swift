import XCTest
import SwiftUI
@testable import VierOpEenRij

/// Geen assert-tests maar een rooktest die de belangrijkste views naar PNG
/// rendert, zodat een build zonder simulator-interactie toch visueel te
/// controleren valt. De bestanden landen in de map uit RENDER_OUTPUT_DIR;
/// zonder die variabele slaat de test over.
@MainActor
final class RenderSmokeTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderKeyScreens() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }

        let engine = GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            seed: 7
        )
        for column in [3, 3, 4, 2, 5, 4, 2] {
            engine.dropDisc(in: column)
        }

        try render(
            BoardView(
                board: engine.board,
                winningCells: [],
                discIndex: engine.discIndex(for:),
                playerName: { engine.players[$0].name },
                isEnabled: true,
                onDrop: { _ in }
            )
            .padding(16)
            .frame(width: 390)
            .background(AppTheme.cream),
            to: outputDirectory.appending(path: "board.png")
        )

        try render(
            PaywallView(entitlements: EntitlementStore(previewUnlocked: false))
                .frame(width: 390, height: 760),
            to: outputDirectory.appending(path: "paywall.png")
        )

        try render(
            GameResultOverlay(
                players: engine.players,
                winnerProfileIDs: [engine.players[0].profileID],
                message: "Lene wint na 9 stenen!",
                discCounts: [9, 8],
                isNewRecord: true,
                animatesIn: false,
                onRematch: {},
                onClose: {}
            )
            .frame(width: 390, height: 760)
            .background(AppTheme.cream),
            to: outputDirectory.appending(path: "result.png")
        )
    }

    private func render(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.metrics, .phone))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "Renderen mislukt voor \(url.lastPathComponent)")
        try XCTUnwrap(image.pngData()).write(to: url)
    }
}
