import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
    private(set) var profiles: [PlayerProfile] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "vieropeenrij-profiles.json") {
        self.fileURL = URL.documentsDirectory.appending(path: filename)
        load()
    }

    /// Test seam.
    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    var humanProfiles: [PlayerProfile] {
        profiles.filter { !$0.isComputer }.sorted { $0.createdAt < $1.createdAt }
    }

    func addProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let color = profiles.count % PlayerProfile.avatarPaletteCount
        let profile = PlayerProfile(name: trimmed, avatarColorIndex: color)
        profiles.append(profile)
        save()
    }

    func renameProfile(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = profiles.firstIndex(where: { $0.id == id && !$0.isComputer }) else { return }
        profiles[index].name = trimmed
        save()
    }

    func updateAvatar(id: UUID, colorIndex: Int, symbol: String?) {
        guard let index = profiles.firstIndex(where: { $0.id == id && !$0.isComputer }) else { return }
        profiles[index].avatarColorIndex = colorIndex
        profiles[index].avatarSymbol = symbol
        save()
    }

    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id && !$0.isComputer }
        save()
    }

    /// Werkt na een afgerond spel de statistieken van alle menselijke
    /// deelnemers bij: potjes, winst, gelijkspel, winreeks en snelste winst.
    /// `winnerDiscCount` is het aantal stenen dat de winnaar zelf legde.
    func recordGameResult(players: [GamePlayer], winnerProfileIDs: [UUID], winnerDiscCount: Int) {
        for player in players where !player.isComputer {
            guard let index = profiles.firstIndex(where: { $0.id == player.profileID }) else { continue }
            profiles[index].gamesPlayed += 1
            if winnerProfileIDs.isEmpty {
                profiles[index].draws += 1
                profiles[index].currentStreak = 0
            } else if winnerProfileIDs.contains(player.profileID) {
                profiles[index].wins += 1
                profiles[index].currentStreak += 1
                profiles[index].bestStreak = max(profiles[index].bestStreak, profiles[index].currentStreak)
                if profiles[index].fastestWin == 0 || winnerDiscCount < profiles[index].fastestWin {
                    profiles[index].fastestWin = winnerDiscCount
                }
            } else {
                profiles[index].currentStreak = 0
            }
        }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            profiles = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            profiles = try decoder.decode([PlayerProfile].self, from: data)
                .filter { !$0.isComputer }
        } catch {
            profiles = []
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(profiles.filter { !$0.isComputer })
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Local-only kids app; ignore disk errors silently.
        }
    }
}
