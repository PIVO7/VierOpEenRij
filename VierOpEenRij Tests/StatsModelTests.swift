import XCTest
@testable import VierOpEenRij

/// De statistiekmodellen achter de trofeeënkast en de gezinsrecords.
@MainActor
final class StatsModelTests: XCTestCase {
    private func profile(
        name: String,
        wins: Int = 0,
        games: Int = 0,
        draws: Int = 0,
        bestStreak: Int = 0,
        fastestWin: Int = 0
    ) -> PlayerProfile {
        PlayerProfile(
            name: name,
            wins: wins,
            gamesPlayed: games,
            draws: draws,
            currentStreak: 0,
            bestStreak: bestStreak,
            fastestWin: fastestWin
        )
    }

    // MARK: - Trofeeën

    func testFreshProfileEarnsNothing() {
        let badges = ProfileBadge.collection(for: profile(name: "Lene"))
        XCTAssertFalse(badges.isEmpty)
        XCTAssertTrue(badges.allSatisfy { !$0.isEarned })
    }

    func testBadgeThresholds() {
        let speler = profile(name: "Lene", wins: 5, games: 10, draws: 1, bestStreak: 3, fastestWin: 7)
        let earned = Set(ProfileBadge.collection(for: speler).filter(\.isEarned).map(\.id))
        XCTAssertTrue(earned.isSuperset(of: [
            "eerste-potje", "winnaar", "even-sterk", "hattrick",
            "bliksemwinst", "speelvogel", "winmachine"
        ]))
        // Nét niet gehaald: 5 op rij, winst met ≤ 5 stenen, 10 winsten, 25 potjes.
        XCTAssertTrue(earned.isDisjoint(with: [
            "onverslaanbaar", "turbowinst", "sterspeler", "kampioen", "bordlegende"
        ]))
    }

    func testFastestWinOfZeroEarnsNoSpeedBadges() {
        // 0 betekent "nog geen winst" — dat mag nooit als bliksemwinst tellen.
        let badges = ProfileBadge.collection(for: profile(name: "Lene", games: 3))
        let speed = badges.filter { $0.id == "bliksemwinst" || $0.id == "turbowinst" }
        XCTAssertTrue(speed.allSatisfy { !$0.isEarned })
    }

    // MARK: - Gezinsrecords

    func testHighestValueWinsAndTiesShareTheRecord() {
        let lene = profile(name: "Lene", wins: 4, games: 6)
        let ellis = profile(name: "Ellis", wins: 4, games: 5)
        let noah = profile(name: "Noah", wins: 2, games: 4)

        let record = FamilyRecordMath.record(in: [lene, ellis, noah], value: { $0.wins })
        XCTAssertEqual(record?.value, 4)
        XCTAssertEqual(record?.holders.map(\.name), ["Lene", "Ellis"])
    }

    func testProfilesWithoutGamesDoNotCompete() {
        // Een vers profiel met (corrupte) statistieken telt niet mee zolang
        // het nog geen potje speelde.
        let spook = profile(name: "Spook", wins: 99, games: 0)
        let lene = profile(name: "Lene", wins: 1, games: 1)

        let record = FamilyRecordMath.record(in: [spook, lene], value: { $0.wins })
        XCTAssertEqual(record?.holders.map(\.name), ["Lene"])
        XCTAssertEqual(record?.value, 1)
    }

    func testZeroIsNoRecord() {
        let lene = profile(name: "Lene", games: 2)
        XCTAssertNil(FamilyRecordMath.record(in: [lene], value: { $0.wins }))
    }

    func testFastestWinPicksLowestPositive() {
        let lene = profile(name: "Lene", wins: 1, games: 3, fastestWin: 9)
        let ellis = profile(name: "Ellis", games: 3, fastestWin: 0)
        let noah = profile(name: "Noah", wins: 2, games: 3, fastestWin: 7)

        let record = FamilyRecordMath.record(
            in: [lene, ellis, noah],
            value: { $0.fastestWin },
            best: FamilyRecordMath.lowestPositive
        )
        XCTAssertEqual(record?.value, 7)
        XCTAssertEqual(record?.holders.map(\.name), ["Noah"])
    }

    func testAllZeroFastestWinsMeanNoRecord() {
        let lene = profile(name: "Lene", games: 4)
        let ellis = profile(name: "Ellis", games: 2)
        XCTAssertNil(FamilyRecordMath.record(
            in: [lene, ellis],
            value: { $0.fastestWin },
            best: FamilyRecordMath.lowestPositive
        ))
    }
}
