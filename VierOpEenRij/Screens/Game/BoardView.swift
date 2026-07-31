import SwiftUI

/// Het blauwe bord met zijn 42 gaatjes. Tik op een kolom en de steen valt
/// naar het laagste vrije vakje; de val komt van boven het bord en wordt door
/// het bord zelf afgeknipt, alsof hij er echt in glijdt.
struct BoardView: View {
    let board: Board
    let winningCells: [Board.Cell]
    /// Spelerindex → schijfkleur (0 koraal, 1 amber).
    let discIndex: (Int) -> Int
    /// Spelerindex → naam; voedt de VoiceOver-beschrijving per kolom.
    let playerName: (Int) -> String
    let isEnabled: Bool
    let onDrop: (Int) -> Void

    @Environment(\.metrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let cell = cellSize(for: proxy.size)
            let boardWidth = cell * CGFloat(Board.columns) + m.boardGap * CGFloat(Board.columns - 1) + m.boardPadding * 2
            let boardHeight = cell * CGFloat(Board.rows) + m.boardGap * CGFloat(Board.rows - 1) + m.boardPadding * 2

            ZStack {
                boardFace(width: boardWidth, height: boardHeight, cell: cell)
                discLayer(width: boardWidth, height: boardHeight, cell: cell)
                columnButtons(width: boardWidth, height: boardHeight, cell: cell)
            }
            .frame(width: boardWidth, height: boardHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private var aspectRatio: CGFloat {
        CGFloat(Board.columns) / CGFloat(Board.rows)
    }

    private func cellSize(for size: CGSize) -> CGFloat {
        let widthWise = (size.width - m.boardPadding * 2 - m.boardGap * CGFloat(Board.columns - 1)) / CGFloat(Board.columns)
        let heightWise = (size.height - m.boardPadding * 2 - m.boardGap * CGFloat(Board.rows - 1)) / CGFloat(Board.rows)
        return max(min(widthWise, heightWise), 10)
    }

    /// Middelpunt van een vakje; rij 0 ligt onderaan.
    private func center(column: Int, row: Int, cell: CGFloat, boardHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: m.boardPadding + cell / 2 + CGFloat(column) * (cell + m.boardGap),
            y: boardHeight - m.boardPadding - cell / 2 - CGFloat(row) * (cell + m.boardGap)
        )
    }

    private func boardFace(width: CGFloat, height: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            ForEach(0..<Board.columns, id: \.self) { column in
                ForEach(0..<Board.rows, id: \.self) { row in
                    Circle()
                        .fill(AppTheme.sunk)
                        .overlay { Circle().strokeBorder(AppTheme.ink.opacity(0.55), lineWidth: m.thinBorder * 0.8) }
                        .frame(width: cell, height: cell)
                        .position(center(column: column, row: row, cell: cell, boardHeight: height))
                }
            }
        }
        .frame(width: width, height: height)
        .toyBlock(fill: AppTheme.sky, radius: m.cardCorner, depth: m.depth + 1, border: m.border)
    }

    private func discLayer(width: CGFloat, height: CGFloat, cell: CGFloat) -> some View {
        ZStack {
            ForEach(occupiedCells, id: \.cell) { entry in
                let point = center(column: entry.cell.column, row: entry.cell.row, cell: cell, boardHeight: height)
                DiscView(colorIndex: discIndex(entry.player), size: cell * 0.94)
                    .position(point)
                    // De val: de steen komt van boven de bordrand naar zijn
                    // vakje; het bord knipt het stuk erboven weg.
                    .transition(discTransition(distance: point.y + cell, row: entry.cell.row))
            }

            ForEach(winningCells, id: \.self) { cellPosition in
                Circle()
                    .strokeBorder(.white, lineWidth: max(cell * 0.09, 3))
                    .frame(width: cell * 0.7, height: cell * 0.7)
                    .position(center(column: cellPosition.column, row: cellPosition.row, cell: cell, boardHeight: height))
                    // Pas nadat de laatste steen geland is; anders staat de
                    // ring er al terwijl de steen nog valt.
                    .transition(.opacity.animation(.easeIn(duration: 0.25).delay(reduceMotion ? 0 : 0.6)))
            }
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: m.cardCorner))
        .allowsHitTesting(false)
    }

    /// De val van een steen. Een gewone veer schoot voorbij zijn doel, zodat
    /// de steen op het einde even dóór het bord zakte; deze stuit blijft
    /// altijd boven zijn vakje. Hoe voller de kolom, hoe korter de val en
    /// dus de animatie. Terugzetten vervaagt gewoon — omgekeerd stuiteren
    /// zou raar staan.
    private func discTransition(distance: CGFloat, row: Int) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let rowsToFall = Board.rows - row
        let duration = 0.38 + 0.05 * Double(rowsToFall)
        return .asymmetric(
            insertion: .modifier(
                active: DropFall(progress: 0, distance: distance),
                identity: DropFall(progress: 1, distance: distance)
            )
            .animation(.linear(duration: duration)),
            removal: .opacity.animation(.easeOut(duration: 0.15))
        )
    }

    private struct OccupiedCell {
        let cell: Board.Cell
        let player: Int
    }

    private var occupiedCells: [OccupiedCell] {
        var cells: [OccupiedCell] = []
        for column in 0..<Board.columns {
            for row in 0..<Board.rows {
                if let player = board[column, row] {
                    cells.append(OccupiedCell(cell: Board.Cell(column: column, row: row), player: player))
                }
            }
        }
        return cells
    }

    private func columnButtons(width: CGFloat, height: CGFloat, cell: CGFloat) -> some View {
        HStack(spacing: m.boardGap) {
            ForEach(0..<Board.columns, id: \.self) { column in
                Button {
                    onDrop(column)
                } label: {
                    Color.clear
                        .frame(width: cell, height: height)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled || !board.canDrop(in: column))
                .accessibilityLabel(String(localized: "Kolom \(column + 1)"))
                .accessibilityValue(columnDescription(column))
                .accessibilityHint(String(localized: "Laat hier je steen vallen"))
            }
        }
        .frame(width: width, height: height)
    }

    /// Wat er in een kolom ligt, in woorden — zonder dit is het bord voor
    /// VoiceOver een raster van naamloze knoppen.
    private func columnDescription(_ column: Int) -> String {
        let filled = board.height(of: column)
        guard filled > 0 else { return String(localized: "leeg") }
        let top = board[column, filled - 1].map(playerName) ?? ""
        return String(localized: "\(filled) stenen, bovenste van \(top)")
    }
}

#Preview {
    var board = Board()
    board.drop(player: 0, in: 3)
    board.drop(player: 1, in: 3)
    board.drop(player: 0, in: 4)
    board.drop(player: 1, in: 2)
    board.drop(player: 0, in: 5)

    return BoardView(
        board: board,
        winningCells: [],
        discIndex: { $0 },
        playerName: { String(localized: "Speler \($0 + 1)") },
        isEnabled: true,
        onDrop: { _ in }
    )
    .padding()
    .background(AppTheme.cream)
    .appMetrics()
}

/// Zwaartekracht in een modifier: de voortgang loopt lineair van 0 naar 1,
/// de stuitcurve vertaalt dat naar een versnelde val met twee kleine stuiten
/// op het vakje. De curve komt nooit boven de 1 uit, dus de steen zakt nooit
/// door zijn vakje heen.
///
/// `@preconcurrency Animatable`: `ViewModifier` is sinds de nieuwe SDK
/// volledig `@MainActor`, terwijl `Animatable` een nonisolated
/// `animatableData` eist. SwiftUI evalueert die tijdens transities gewoon op
/// de main thread, dus de runtime-check is veilig.
private struct DropFall: ViewModifier, @preconcurrency Animatable {
    var progress: CGFloat
    let distance: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(y: -distance * (1 - Self.bounceOut(progress)))
    }

    /// De klassieke bounce-easing (Penner): drie parabolen achter elkaar.
    static func bounceOut(_ t: CGFloat) -> CGFloat {
        let n1: CGFloat = 7.5625
        let d1: CGFloat = 2.75
        var t = t
        if t < 1 / d1 {
            return n1 * t * t
        } else if t < 2 / d1 {
            t -= 1.5 / d1
            return n1 * t * t + 0.75
        } else if t < 2.5 / d1 {
            t -= 2.25 / d1
            return n1 * t * t + 0.9375
        } else {
            t -= 2.625 / d1
            return n1 * t * t + 0.984375
        }
    }
}
