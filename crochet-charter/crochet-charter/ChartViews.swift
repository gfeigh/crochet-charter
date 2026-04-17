import SwiftUI

// MARK: - Single Stitch Cell

struct StitchCell: View {
    let stitch: Stitch
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(stitch.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.15)
                        .strokeBorder(stitch.color.opacity(0.5), lineWidth: 0.75)
                )
            Text(stitch.symbol)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(stitch.color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chart Row

struct ChartRowView: View {
    let row: StitchRow
    let cellSize: CGFloat
    let showRowNumbers: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showRowNumbers {
                Text("\(row.rowNumber)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .trailing)
                    .padding(.trailing, 4)
            }
            HStack(spacing: 1) {
                ForEach(Array(row.stitches.enumerated()), id: \.offset) { _, stitch in
                    StitchCell(stitch: stitch, size: cellSize)
                }
            }
            if let count = row.stitchCount {
                Text("(\(count))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.leading, 6)
            }
        }
    }
}

// MARK: - Chart View

struct ChartView: View {
    let pattern: ParsedPattern
    @State private var scale: CGFloat = 1.0
    @State private var cellSize: CGFloat = 32
    let showRowNumbers: Bool

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(pattern.rows.reversed()) { row in
                    ChartRowView(row: row, cellSize: cellSize, showRowNumbers: showRowNumbers)
                }
            }
            .padding()
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.2), value: scale)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(0.4, min(3.0, value))
                }
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    withAnimation { scale = max(0.4, scale - 0.2) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                Button {
                    withAnimation { scale = 1.0 }
                } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                Button {
                    withAnimation { scale = min(3.0, scale + 0.2) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
        }
    }
}

// MARK: - Legend View

struct LegendView: View {
    let stitches: [Stitch]

    // Deduplicate while preserving order
    private var unique: [Stitch] {
        var seen: [String] = []
        return stitches.filter { s in
            let key = s.shortName
            if seen.contains(key) { return false }
            seen.append(key)
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Legend")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            Divider().padding(.vertical, 6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                ForEach(unique, id: \.shortName) { stitch in
                    HStack(spacing: 8) {
                        StitchCell(stitch: stitch, size: 28)
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stitch.color.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }
}
