import SwiftUI

// MARK: - Layout constants

private enum C {
    static let gap: CGFloat = 2          // gap between cells
    static let cornerFan: CGFloat = 45   // degrees half-spread for corner stitches
    static let ringSpacing: CGFloat = 1.5 // multiplier: radius grows by cellSize * this per ring
    static let labelOffset: CGFloat = 14  // px above ring boundary for round label
}

// MARK: - Cell placement description

private struct CellPlacement {
    let x: CGFloat        // top-left of cell before rotation
    let y: CGFloat
    let angleDeg: Double  // rotation so bottom of cell faces center
    let stitch: Stitch
    let isCorner: Bool
}

// MARK: - Granny Square Chart View (container)

struct GrannyChartView: View {
    let pattern: ParsedPattern
    @State private var cellSize: CGFloat = 26
    @State private var showLegend = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar-style controls
            HStack(spacing: 12) {
                Text("Zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $cellSize, in: 14...44, step: 2)
                Text("\(Int(cellSize)) pt")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView([.horizontal, .vertical]) {
                GrannyChartCanvas(pattern: pattern, cellSize: cellSize)
                    .padding(32)
            }

            if showLegend {
                Divider()
                LegendView(stitches: pattern.allStitches)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(pattern.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3)) { showLegend.toggle() }
                } label: {
                    Image(systemName: showLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                }
            }
        }
    }
}

// MARK: - Canvas renderer

struct GrannyChartCanvas: View {
    let pattern: ParsedPattern
    let cellSize: CGFloat

    // Pre-compute all cell placements so we can size the canvas correctly
    private var allPlacements: [[CellPlacement]] {
        computePlacements()
    }

    private var canvasSize: CGSize {
        var maxR: CGFloat = cellSize  // at least one cell
        for (ri, _) in pattern.rounds.enumerated() {
            maxR = max(maxR, ringRadius(for: ri))
        }
        let side = (maxR + cellSize + C.labelOffset + 20) * 2
        return CGSize(width: side, height: side)
    }

    var body: some View {
        let size = canvasSize
        let placements = allPlacements
        Canvas { ctx, _ in
            let cx = size.width / 2
            let cy = size.height / 2
            drawChart(ctx: ctx, cx: cx, cy: cy, placements: placements)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Placement computation

    private func ringRadius(for roundIndex: Int) -> CGFloat {
        if roundIndex == 0 { return 0 }
        return CGFloat(roundIndex) * cellSize * C.ringSpacing + cellSize * 0.5
    }

    private func computePlacements() -> [[CellPlacement]] {
        pattern.rounds.enumerated().map { (ri, round) in
            switch round.shape {
            case .center:
                return centerPlacements(round: round)
            case .circular:
                return circularPlacements(round: round, radius: ringRadius(for: ri))
            case .square:
                return squarePlacements(round: round, radius: ringRadius(for: ri))
            }
        }
    }

    // Center ring: magic ring in center, surrounding stitches in a small circle
    private func centerPlacements(round: PatternRound) -> [CellPlacement] {
        let tokens = round.tokens
        guard !tokens.isEmpty else { return [] }

        // First stitch (MR) goes dead center
        var result = [CellPlacement(x: -cellSize/2, y: -cellSize/2, angleDeg: 0,
                                    stitch: tokens[0].stitch, isCorner: false)]
        let rest = Array(tokens.dropFirst())
        guard !rest.isEmpty else { return result }

        let r = cellSize * 0.9
        for (i, token) in rest.enumerated() {
            let angle = CGFloat(i) / CGFloat(rest.count) * .pi * 2 - .pi/2
            let px = cos(angle) * r - cellSize/2
            let py = sin(angle) * r - cellSize/2
            let deg = (angle * 180 / .pi) + 90
            result.append(CellPlacement(x: px, y: py, angleDeg: deg,
                                        stitch: token.stitch, isCorner: false))
        }
        return result
    }

    // Circular round: even distribution around a circle
    private func circularPlacements(round: PatternRound, radius: CGFloat) -> [CellPlacement] {
        let tokens = round.tokens
        guard !tokens.isEmpty else { return [] }
        let n = CGFloat(tokens.count)
        return tokens.enumerated().map { (i, token) in
            let angle = CGFloat(i) / n * .pi * 2 - .pi/2
            let px = cos(angle) * radius - cellSize/2
            let py = sin(angle) * radius - cellSize/2
            let deg = (angle * 180 / .pi) + 90
            return CellPlacement(x: px, y: py, angleDeg: deg,
                                 stitch: token.stitch, isCorner: token.isCorner)
        }
    }

    // Square round: stitches distributed along 4 sides; corner stitches fan outward at 45°
    private func squarePlacements(round: PatternRound, radius: CGFloat) -> [CellPlacement] {
        let tokens = round.tokens
        guard !tokens.isEmpty else { return [] }

        // Split tokens into 4 quadrants by finding the 4 corner groups
        let sides = splitIntoSides(tokens: tokens)
        var result: [CellPlacement] = []

        // Side base angles (direction the side faces, i.e. outward direction):
        // top=270° (up), right=0°, bottom=90°, left=180°
        let sideAngles: [CGFloat] = [-.pi/2, 0, .pi/2, .pi]  // in radians, outward

        for (sideIdx, sideTokens) in sides.enumerated() {
            let outward = sideAngles[sideIdx]
            result += placeSide(tokens: sideTokens, sideIndex: sideIdx,
                                outwardAngle: outward, radius: radius)
        }
        return result
    }

    /// Split the token array into 4 sides by locating 4 corner clusters.
    /// Each corner cluster starts a new side.
    private func splitIntoSides(tokens: [StitchToken]) -> [[StitchToken]] {
        // Find indices where a corner group starts (first corner-marked stitch after a non-corner)
        var cornerStarts: [Int] = []
        var inCorner = false
        for (i, t) in tokens.enumerated() {
            if t.isCorner && !inCorner {
                cornerStarts.append(i)
                inCorner = true
            } else if !t.isCorner {
                inCorner = false
            }
        }

        guard cornerStarts.count == 4 else {
            // Fallback: split evenly
            let quarter = tokens.count / 4
            return (0..<4).map { s in Array(tokens[s*quarter..<min((s+1)*quarter, tokens.count)]) }
        }

        // Each side = tokens from this corner start to just before the next
        var sides: [[StitchToken]] = []
        for (ci, start) in cornerStarts.enumerated() {
            let end = ci + 1 < cornerStarts.count ? cornerStarts[ci+1] : tokens.count
            sides.append(Array(tokens[start..<end]))
        }
        return sides
    }

    /// Place tokens along one side of the square, with corners fanning at the start.
    private func placeSide(tokens: [StitchToken], sideIndex: Int,
                           outwardAngle: CGFloat, radius: CGFloat) -> [CellPlacement] {
        guard !tokens.isEmpty else { return [] }

        let step = cellSize + C.gap

        // Separate corner tokens (at the start of the side) from side tokens
        var cornerTokens: [StitchToken] = []
        var sideTokens: [StitchToken] = []
        var pastCorner = false
        for t in tokens {
            if !pastCorner && t.isCorner { cornerTokens.append(t) }
            else { pastCorner = true; sideTokens.append(t) }
        }

        var result: [CellPlacement] = []

        // Corner stitches: fan outward from the corner point at ±cornerFan degrees
        let cornerAngle = outwardAngle - .pi/4  // diagonal direction of this corner
        // Corner position on the square ring
        let cornerX = cos(cornerAngle) * radius * 1.2
        let cornerY = sin(cornerAngle) * radius * 1.2

        if !cornerTokens.isEmpty {
            let n = CGFloat(cornerTokens.count)
            let spreadRad = CGFloat(C.cornerFan) * .pi / 180
            let halfSpread = spreadRad * (n - 1) / 2
            for (i, token) in cornerTokens.enumerated() {
                let fanAngle = cornerAngle - halfSpread + CGFloat(i) / max(n-1, 1) * spreadRad * (n-1)
                let dist = radius * 0.25 + CGFloat(i) * step * 0.3
                let px = cornerX + cos(fanAngle) * dist - cellSize/2
                let py = cornerY + sin(fanAngle) * dist - cellSize/2
                let deg = (fanAngle * 180 / .pi) + 90
                result.append(CellPlacement(x: px, y: py, angleDeg: deg,
                                            stitch: token.stitch, isCorner: true))
            }
        }

        // Side stitches: distributed linearly along the side between corners
        // The side runs perpendicular to outwardAngle
        let perpAngle = outwardAngle + .pi/2
        if !sideTokens.isEmpty {
            let n = sideTokens.count
            let totalWidth = CGFloat(n - 1) * step
            for (i, token) in sideTokens.enumerated() {
                let offset = -totalWidth/2 + CGFloat(i) * step
                let px = cos(outwardAngle) * radius + cos(perpAngle) * offset - cellSize/2
                let py = sin(outwardAngle) * radius + sin(perpAngle) * offset - cellSize/2
                let deg = (outwardAngle * 180 / .pi) + 90
                result.append(CellPlacement(x: px, y: py, angleDeg: deg,
                                            stitch: token.stitch, isCorner: false))
            }
        }

        return result
    }

    // MARK: - Drawing

    private func drawChart(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                           placements: [[CellPlacement]]) {
        // Draw ring guides first (behind cells)
        for (ri, round) in pattern.rounds.enumerated() {
            guard round.shape != .center else { continue }
            let r = ringRadius(for: ri)
            drawRingGuide(ctx: ctx, cx: cx, cy: cy, round: round, radius: r, roundIndex: ri)
        }

        // Draw all cells
        for roundPlacements in placements {
            for p in roundPlacements {
                drawCell(ctx: ctx, placement: p, cx: cx, cy: cy)
            }
        }
    }

    private func drawRingGuide(ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                               round: PatternRound, radius: CGFloat, roundIndex: Int) {
        let guideColor = Color.secondary.opacity(0.15)
        let style = StrokeStyle(lineWidth: 0.5, dash: [4, 4])

        if round.shape == .square {
            let pad = radius + cellSize * 0.6
            ctx.stroke(Path(CGRect(x: cx-pad, y: cy-pad, width: pad*2, height: pad*2)),
                       with: .color(guideColor), style: style)
        } else {
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx-radius, y: cy-radius, width: radius*2, height: radius*2)),
                with: .color(guideColor), style: style
            )
        }

        // Round label above guide
        let labelY: CGFloat
        if round.shape == .square {
            labelY = cy - (radius + cellSize * 0.6) - C.labelOffset
        } else {
            labelY = cy - radius - C.labelOffset
        }
        ctx.draw(
            Text("Rnd \(round.roundNumber)")
                .font(.system(size: 9))
                .foregroundColor(.secondary),
            at: CGPoint(x: cx, y: labelY)
        )
    }

    private func drawCell(ctx: GraphicsContext, placement: CellPlacement, cx: CGFloat, cy: CGFloat) {
        let x = cx + placement.x
        let y = cy + placement.y
        let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
        let center = CGPoint(x: x + cellSize/2, y: y + cellSize/2)
        let corner = cellSize * 0.15
        let stitch = placement.stitch

        var drawCtx = ctx
        let rad = CGFloat(placement.angleDeg) * .pi / 180
        drawCtx.concatenate(
            CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rad)
                .translatedBy(x: -center.x, y: -center.y)
        )

//        // Background
//        drawCtx.fill(
//            Path(roundedRect: rect, cornerRadius: corner),
//            with: .color(stitch.color.opacity(placement.isCorner ? 0.22 : 0.12))
//        )
//
//        // Border — slightly stronger for corner cells
//        drawCtx.stroke(
//            Path(roundedRect: rect, cornerRadius: corner),
//            with: .color(stitch.color.opacity(placement.isCorner ? 0.7 : 0.4)),
//            lineWidth: placement.isCorner ? 1.0 : 0.75
//        )

        // Direction pip (inward indicator)
        drawCtx.fill(
            Path(ellipseIn: CGRect(x: center.x - 1.5, y: y + cellSize - 5, width: 3, height: 3)),
            with: .color(stitch.color.opacity(0.5))
        )

        // Symbol
        drawCtx.draw(
            Text(stitch.symbol)
                .font(.system(size: cellSize * 0.46, weight: .medium))
                .foregroundColor(stitch.color),
            at: center
        )
    }
}

// MARK: - Legend View

struct LegendView: View {
    let stitches: [Stitch]

    private var unique: [Stitch] {
        var seen: [String] = []
        return stitches.filter { seen.contains($0.shortName) ? false : (seen.append($0.shortName) == () || true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Legend")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)
            Divider().padding(.vertical, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                ForEach(unique, id: \.shortName) { stitch in
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stitch.color.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(stitch.color.opacity(0.4), lineWidth: 0.75))
                            Text(stitch.symbol)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(stitch.color)
                        }
                        .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stitch.shortName.uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(stitch.color)
                            Text(stitch.fullName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(stitch.color.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal).padding(.bottom)
        }
        .background(Color(.systemBackground))
    }
}
