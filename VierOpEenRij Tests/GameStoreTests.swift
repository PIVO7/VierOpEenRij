import XCTest
@testable import VierOpEenRij

@MainActor
final class GameStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = URL.temporaryDirectory.appending(path: "game-test-\(UUID()).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func snapshot(moves: [Int]) -> GameSnapshot {
        GameSnapshot(
            mode: .versusFriends,
            players: [
                GamePlayer(profile: PlayerProfile(name: "Lene")),
                GamePlayer(profile: PlayerProfile(name: "Ellis", avatarColorIndex: 1))
            ],
            startingPlayerIndex: 0,
            moves: moves,
            turnMessage: "",
            savedAt: .now
        )
    }

    func testSaveAndReload() async {
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot(moves: [3, 4]))
        await store.flush()

        let reloaded = GameStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.savedGame?.moves, [3, 4])
        XCTAssertEqual(reloaded.savedGame?.summaryTitle, "Lene · Ellis")
    }

    func testClearRemovesFile() async {
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot(moves: [3]))
        await store.flush()
        store.clear()
        await store.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertNil(GameStore(fileURL: fileURL).savedGame)
    }

    func testFinishedGameIsNotResumed() async {
        // Kolom 2 vier keer voor de beginner: dat spel is al gewonnen.
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot(moves: [2, 5, 2, 5, 2, 5, 2]))
        await store.flush()

        let reloaded = GameStore(fileURL: fileURL)
        XCTAssertNil(reloaded.savedGame)
    }

    func testCorruptMovesAreNotResumed() async {
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot(moves: Array(repeating: 0, count: 9)))
        await store.flush()

        XCTAssertNil(GameStore(fileURL: fileURL).savedGame)
    }

    func testLatestWriteWins() async {
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot(moves: [1]))
        store.save(snapshot(moves: [1, 2]))
        store.save(snapshot(moves: [1, 2, 3]))
        await store.flush()

        XCTAssertEqual(GameStore(fileURL: fileURL).savedGame?.moves, [1, 2, 3])
    }
}
