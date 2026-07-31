import XCTest
@testable import VierOpEenRij

@MainActor
final class ProfileStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = URL.temporaryDirectory.appending(path: "profiles-test-\(UUID()).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testAddAndPersistProfile() {
        let store = ProfileStore(fileURL: fileURL)
        store.addProfile(name: "  Lene ")
        XCTAssertEqual(store.humanProfiles.map(\.name), ["Lene"])

        let reloaded = ProfileStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.humanProfiles.map(\.name), ["Lene"])
    }

    func testRecordWinUpdatesStreakAndFastestWin() {
        let store = ProfileStore(fileURL: fileURL)
        store.addProfile(name: "Lene")
        store.addProfile(name: "Ellis")
        let lene = store.humanProfiles[0]
        let ellis = store.humanProfiles[1]
        let players = [GamePlayer(profile: lene), GamePlayer(profile: ellis)]

        store.recordGameResult(players: players, winnerProfileIDs: [lene.id], winnerDiscCount: 12)
        store.recordGameResult(players: players, winnerProfileIDs: [lene.id], winnerDiscCount: 9)

        let updated = store.humanProfiles[0]
        XCTAssertEqual(updated.wins, 2)
        XCTAssertEqual(updated.gamesPlayed, 2)
        XCTAssertEqual(updated.currentStreak, 2)
        XCTAssertEqual(updated.bestStreak, 2)
        XCTAssertEqual(updated.fastestWin, 9)

        let loser = store.humanProfiles[1]
        XCTAssertEqual(loser.wins, 0)
        XCTAssertEqual(loser.gamesPlayed, 2)
        XCTAssertEqual(loser.currentStreak, 0)
        XCTAssertEqual(loser.fastestWin, 0)
    }

    func testSlowerWinKeepsFastestRecord() {
        let store = ProfileStore(fileURL: fileURL)
        store.addProfile(name: "Lene")
        let lene = store.humanProfiles[0]
        let players = [GamePlayer(profile: lene)]

        store.recordGameResult(players: players, winnerProfileIDs: [lene.id], winnerDiscCount: 8)
        store.recordGameResult(players: players, winnerProfileIDs: [lene.id], winnerDiscCount: 15)
        XCTAssertEqual(store.humanProfiles[0].fastestWin, 8)
    }

    func testDrawCountsAndBreaksStreak() {
        let store = ProfileStore(fileURL: fileURL)
        store.addProfile(name: "Lene")
        let lene = store.humanProfiles[0]
        let players = [GamePlayer(profile: lene)]

        store.recordGameResult(players: players, winnerProfileIDs: [lene.id], winnerDiscCount: 10)
        store.recordGameResult(players: players, winnerProfileIDs: [], winnerDiscCount: 0)

        let updated = store.humanProfiles[0]
        XCTAssertEqual(updated.draws, 1)
        XCTAssertEqual(updated.currentStreak, 0)
        XCTAssertEqual(updated.bestStreak, 1)
    }

    func testComputerIsNeverRecorded() {
        let store = ProfileStore(fileURL: fileURL)
        store.addProfile(name: "Lene")
        let lene = store.humanProfiles[0]
        let robot = PlayerProfile.computer(level: .medium)
        let players = [GamePlayer(profile: lene), GamePlayer(profile: robot)]

        store.recordGameResult(players: players, winnerProfileIDs: [robot.id], winnerDiscCount: 7)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.humanProfiles[0].gamesPlayed, 1)
        XCTAssertEqual(store.humanProfiles[0].wins, 0)
    }

    func testAvatarPaletteCountMatchesBadge() async {
        // De avatarkiezer telt op dit aantal; als het palet krimpt zonder
        // deze constante mee te nemen, crasht de modulo-logica niet maar
        // kiezen kinderen kleuren die er niet zijn.
        let count = await MainActor.run { AvatarBadge.palette.count }
        XCTAssertEqual(PlayerProfile.avatarPaletteCount, count)
    }
}
