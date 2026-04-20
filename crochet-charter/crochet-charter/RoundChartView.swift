import SwiftUI

// MARK: - Chart Mode

enum ChartMode: String, CaseIterable {
    case squareRings = "Square rings"
    case circular    = "Circular"
    case flatGrid    = "Flat grid"

    var systemImage: String {
        switch self {
        case .squareRings: return "square.on.square"
        case .circular:    return "circle.grid.cross"
        case .flatGrid:    return "square.grid.3x3"
        }
    }
}

// MARK: - Round Chart Container

struct RoundChartContainerView: View {
    let pattern: ParsedPattern
    @State private var mode: ChartMode = .squareRings
    @State private var cellSize: CGFloat = 28
    @State private var showLegend = true
    @State private var faceCenter = true   // NEW

    var body: some View {
        VStack(spacing: 0) {
            // Mode picker
            Picker("Chart mode", selection: $mode) {
                ForEach(ChartMode.allCases, id: \.self) { m in
                    Label(m.rawValue, systemImage: m.systemImage).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)

            // Zoom + face-center controls
            HStack {
                Text("Zoom")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $cellSize, in: 14...48, step: 2)
                Text("\(Int(cellSize))pt")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
                Divider().frame(height: 16).padding(.horizontal, 4)
                Toggle("Face center", isOn: $faceCenter)
                    .font(.caption)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text("Face center")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Chart canvas
            ScrollView([.horizontal, .vertical]) {
                RoundChartCanvas(pattern: pattern, mode: mode, cellSize: cellSize, faceCenter: faceCenter)
                    .padding(24)
            }

            if showLegend {
                Divider()
                LegendView(stitches: pattern.rows.flatMap(\.stitches))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3)) { showLegend.toggle() }
                } label: {
                    Image(systemName: showLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                }
            }
        }
        .navigationTitle(pattern.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Canvas Renderer

struct RoundChartCanvas: View {
    let pattern: ParsedPattern
    let mode: ChartMode
    let cellSize: CGFloat
    let faceCenter: Bool        // NEW

    private let gap: CGFloat = 2

    var body: some View {
        Canvas { ctx, size in
            switch mode {
            case .squareRings: drawSquareRings(ctx: ctx, canvasSize: size)
            case .circular:    drawCircular(ctx: ctx, canvasSize: size)
            case .flatGrid:    drawFlatGrid(ctx: ctx, canvasSize: size)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    // MARK: Computed canvas size

    private var canvasSize: CGSize {
        switch mode {
        case .squareRings:
            let rings = pattern.rows.count
            let side = CGFloat(rings * 2 + 1) * (cellSize + gap) + 60
            return CGSize(width: side, height: side)
        case .circular:
            let rings = pattern.rows.count
            let maxR = CGFloat(rings) * (cellSize + 4) * 1.8 + cellSize + 40
            return CGSize(width: maxR * 2, height: maxR * 2)
        case .flatGrid:
            let maxCols = CGFloat(pattern.rows.map { $0.stitches.count }.max() ?? 1)
            let rows = CGFloat(pattern.rows.count)
            return CGSize(
                width: maxCols * (cellSize + gap) + 80,
                height: rows * (cellSize + gap) + 40
            )
        }
    }

    // MARK: Square rings

    private func drawSquareRings(ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width / 2
        let cy = canvasSize.height / 2
        let step = cellSize + gap
        for (ri, round) in pattern.rows.enumerated() {
            print(ri)
            if ri == 0 {
                if let first = round.stitches.first {
                    drawCell(ctx: ctx, x: cx - cellSize/2, y: cy - cellSize/2, stitch: first, angleDeg: nil)
                    print(first.symbol)
                }
                continue
            }

            let ring = CGFloat(ri)
            let perSide = Int(ring) * 2
            let startX = cx - ring * step - cellSize/2
            let startY = cy - ring * step - cellSize/2

            // Each side has a fixed inward-facing rotation:
            //   Top side  → faces downward  (0°)
            //   Right side → faces leftward  (90°)
            //   Bottom side → faces upward   (180°)
            //   Left side  → faces rightward (270°)
            let sides: [(angle: Double, positions: [(CGFloat, CGFloat)])] = [
                (0, (0..<perSide).map { i in (startX + CGFloat(i)*step, startY) }),
                (90, (0..<perSide).map { i in (startX + CGFloat(perSide)*step, startY + CGFloat(i)*step) }),
                (180,   (0..<perSide).map { i in (startX + CGFloat(perSide-i)*step, startY + CGFloat(perSide)*step) }),
                (270,  (0..<perSide).map { i in (startX, startY + CGFloat(perSide-i)*step) }),
            ]

            let stitches = round.stitches
            let n = CGFloat(stitches.count)
            var idx = 0
            for side in sides {
                for (px, py) in side.positions {
                    let st = stitches[idx % stitches.count]
                    print(st.symbol)
                    let angle = (Double(idx-1 % stitches.count) / n) * .pi * 2 - .pi / 2
                    let rotateDeg = (faceCenter ? (angle * 180 / .pi) + 90 : nil) ?? 0.0
                    drawCell(ctx: ctx, x: px, y: py, stitch: st,
                             angleDeg: faceCenter ? Double(rotateDeg) : nil)
                    idx += 1
                }
            }
            
//            for (si, st) in stitches.enumerated() {
//                let angle = (Double(si) / n) * .pi * 2 - .pi / 2
//                let px = cx + cos(angle) * radius - cellSize/2
//                let py = cy + sin(angle) * radius - cellSize/2
//                // Rotate so the bottom of the cell points toward the center.
//                // The cell's natural "down" is 0°; the inward direction from angle is (angle + π).
//                // In degrees: convert angle to degrees then add 90° so bottom edge faces inward.
//                let rotateDeg = (faceCenter ? (angle * 180 / .pi) + 90 : nil) ?? 0.0
//                drawCell(ctx: ctx, x: px, y: py, stitch: st, angleDeg: Double(rotateDeg))
//            }

            // Dashed ring boundary
            let pad = ring * step + cellSize/2 + 4
            ctx.stroke(
                Path(CGRect(x: cx - pad, y: cy - pad, width: pad*2, height: pad*2)),
                with: .color(.secondary.opacity(0.2)),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
            )

            ctx.draw(
                Text("Rnd \(round.rowNumber)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary),
                at: CGPoint(x: cx, y: cy - pad - 10)
            )
        }
    }

    // MARK: Circular

    private func drawCircular(ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width / 2
        let cy = canvasSize.height / 2

        for (ri, round) in pattern.rows.enumerated() {
            print(ri)
            if ri == 0 {
                if let first = round.stitches.first {
                    drawCell(ctx: ctx, x: cx - cellSize/2, y: cy - cellSize/2, stitch: first, angleDeg: nil)
                }
                continue
            }

            let radius = CGFloat(ri) * (cellSize + 4) * 1.8
            let stitches = round.stitches
            let n = CGFloat(stitches.count)

            for (si, st) in stitches.enumerated() {
                let angle = (Double(si) / n) * .pi * 2 - .pi / 2
                let px = cx + cos(angle) * radius - cellSize/2
                let py = cy + sin(angle) * radius - cellSize/2
                // Rotate so the bottom of the cell points toward the center.
                // The cell's natural "down" is 0°; the inward direction from angle is (angle + π).
                // In degrees: convert angle to degrees then add 90° so bottom edge faces inward.
                let rotateDeg = (faceCenter ? (angle * 180 / .pi) + 90 : nil) ?? 0.0
                drawCell(ctx: ctx, x: px, y: py, stitch: st, angleDeg: Double(rotateDeg))
            }

            // Dashed circle
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius*2, height: radius*2)),
                with: .color(.secondary.opacity(0.15)),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
            )

            ctx.draw(
                Text("Rnd \(round.rowNumber)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary),
                at: CGPoint(x: cx, y: cy - radius - 12)
            )
        }
    }

    // MARK: Flat grid

    private func drawFlatGrid(ctx: GraphicsContext, canvasSize: CGSize) {
        let maxCols = pattern.rows.map { $0.stitches.count }.max() ?? 1
        let labelWidth: CGFloat = 52
        let step = cellSize + gap

        for (ri, round) in pattern.rows.enumerated() {
            let rowOffset = CGFloat((maxCols - round.stitches.count)) / 2 * step
            let y = CGFloat(ri) * step + 20

            // Row label
            ctx.draw(
                Text("Rnd \(round.rowNumber)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary),
                at: CGPoint(x: labelWidth/2, y: y + cellSize/2)
            )

            for (si, st) in round.stitches.enumerated() {
                let x = labelWidth + rowOffset + CGFloat(si) * step
                drawCell(ctx: ctx, x: x, y: y, stitch: st, angleDeg: nil)
            }
        }
    }

    // MARK: Cell drawing

    /// Draws a stitch cell at (x, y). If `angleDeg` is provided and `faceCenter` is true,
    /// the cell is rotated around its center so its bottom edge faces the center ring.
    private func drawCell(ctx: GraphicsContext, x: CGFloat, y: CGFloat, stitch: Stitch, angleDeg: Double?) {
        let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
        let center = CGPoint(x: x + cellSize/2, y: y + cellSize/2)
        let corner = cellSize * 0.15

        var drawCtx = ctx

        // Apply rotation around cell center
        if let deg = angleDeg {
            let radians = CGFloat(deg) * .pi / 180
            drawCtx.concatenate(
                CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: radians)
                    .translatedBy(x: -center.x, y: -center.y)
            )
        }

        // Background fill
//        drawCtx.fill(
//            Path(roundedRect: rect, cornerRadius: corner),
//            with: .color(stitch.color.opacity(0.12))
//        )
//
//        // Border
//        drawCtx.stroke(
//            Path(roundedRect: rect, cornerRadius: corner),
//            with: .color(stitch.color.opacity(0.45)),
//            lineWidth: 0.75
//        )

        // Inward-facing direction pip — small dot at the bottom of the cell
        if angleDeg != nil {
            drawCtx.fill(
                Path(ellipseIn: CGRect(x: center.x - 1.5, y: y + cellSize - 5, width: 3, height: 3)),
                with: .color(stitch.color.opacity(0.6))
            )
        }

        // Symbol
        drawCtx.draw(
            Text(stitch.symbol)
                .font(.system(size: cellSize * 0.46, weight: .medium))
                .foregroundColor(stitch.color),
            at: center
        )
    }
}
