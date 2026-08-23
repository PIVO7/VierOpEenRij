# Vier op een rij (SwiftUI)

iOS-app voor kinderen: klassiek Vier op een rij met profielen, lokale
multiplayer en solo tegen de computer. Zusje van [Dobbel](https://github.com/PIVO7/Dobbel): zelfde
speelgoedstijl, zelfde thema's en dezelfde Gezinsversie-aankoop.

## Features

- **Profielen** — naam + avatar + overwinningen en gespeelde spellen (lokaal opgeslagen)
- **Tegen elkaar** — 2 spelers, beurten op één apparaat
- **Tegen de computer** — Dommel (makkelijk), Robbie (gemiddeld) en Professor Punt (minimax)
- **Valanimatie** — tik op een kolom en de steen valt in het bord
- **Zet terug** — per ongeluk getikt? Eén tik en de steen komt er weer uit
- **Bewaard spel** — stop halverwege en speel later verder
- **Gezinsversie** (eenmalige aankoop, gezinsdeelbaar): alle tegenstanders,
  alle thema's (Snoep, Oceaan, Nacht) en statistieken per speler — met
  ouder-poort vóór de kassa

## Openen in Xcode

Genereer het project eerst met [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`project.yml` is de bron van waarheid):

```bash
brew install xcodegen   # eenmalig
xcodegen generate
open VierOpEenRij.xcodeproj
```

Kies een simulator of iPhone, druk op Run. Vereisten: Xcode 15+, iOS 17+.

Vanaf de terminal bouwen of testen:

```bash
xcodebuild build -project VierOpEenRij.xcodeproj -scheme VierOpEenRij \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## App-structuur

```
project.yml                 # XcodeGen-definitie (repo-root)
VierOpEenRij.storekit       # StoreKit-testconfiguratie (Gezinsversie)
VierOpEenRij/
  VierOpEenRijApp.swift
  Models/                   # PlayerProfile, GameMode
  Game/                     # Board, GameEngine, GameSnapshot
  AI/                       # ComputerAI (heuristiek + minimax), persona's
  Persistence/              # ProfileStore + GameStore (JSON in Documents)
  Components/               # Disc, avatar, confetti, dialoog
  Screens/                  # Home, Profiles, Setup, Game, Rules, Settings
  Store/                    # EntitlementStore, PaywallView, ouder-poort
  Theme/                    # Speelgoedstijl + thema's + maten
VierOpEenRij Tests/         # Bord, AI, engine, profielen, opslag
```

## Spelregels (kort)

1. Tik op een kolom; je steen valt naar het laagste vrije vakje.
2. Om de beurt — wie begint speelt koraal, de ander amber.
3. **Vier op een rij** (liggend, staand of schuin) wint.
4. Bord vol zonder rij van vier: gelijkspel.

## Ontwerpkeuzes

| Onderdeel | Keuze |
|-----------|--------|
| UI-taal | Nederlands (voor de kids) |
| Data | Lokaal JSON, geen account/cloud |
| AI | Makkelijk: willekeur · Gemiddeld: winnen/blokkeren + midden · Moeilijk: minimax (diepte 7) |
| Architectuur | `@Observable` game engine + SwiftUI views |
| Monetisatie | Eén non-consumable "Gezinsversie", zelfde opzet als Dobbel |

## Tests

In Xcode: `⌘U`, of:

```bash
xcodebuild test -project VierOpEenRij.xcodeproj -scheme VierOpEenRij \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
