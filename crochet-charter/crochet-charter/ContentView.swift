import SwiftUI

// MARK: - Pattern Input View

struct PatternInputView: View {
    @State private var patternText: String = ""
    @State private var parsedPattern: ParsedPattern?
    @State private var showChart = false
    @State private var showRowNumbers = true
    @FocusState private var isEditorFocused: Bool

    private let parser = PatternParser()

    private let examplePattern = """
    Magic Granny Square
    Rnd 1: Magic ring, ch 3 (counts as dc), 2 dc, ch 2, (3 dc, ch 2) 3 times, sl st to top of ch-3 
    Rnd 2: sl st to ch-2 sp, ch 3, 2 dc, ch 2, 3 dc, ch 1, (3 dc, ch 2, 3 dc, ch 1) 3 times, sl st 
    Rnd 3: sl st to ch-2 sp, ch 3, 2 dc, ch 2, 3 dc, ch 1, 3 dc in ch-1 sp, ch 1, (3 dc, ch 2, 3 dc, ch 1, 3 dc in ch-1 sp, ch 1) 3 times, sl st 
    """

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Editor area
                ZStack(alignment: .topLeading) {
                    if patternText.isEmpty {
                        Text("Paste or type your crochet pattern here…\n\nExample:\nRow 1: ch 12\nRow 2: sc in each ch across (12 sts)\nRow 3: inc, sc 10, inc (14 sts)")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $patternText)
                        .font(.system(.body, design: .monospaced))
                        .focused($isEditorFocused)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()

                // Controls
                VStack(spacing: 10) {
                    Toggle("Show row numbers", isOn: $showRowNumbers)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button {
                            patternText = examplePattern
                            isEditorFocused = false
                        } label: {
                            Label("Load example", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            patternText = ""
                        } label: {
                            Label("Clear", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .padding(.horizontal)

                    Button {
                        isEditorFocused = false
                        parsedPattern = parser.parse(text: patternText)
                        showChart = true
                    } label: {
                        Label("Generate chart", systemImage: "chart.bar.doc.horizontal")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .disabled(patternText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom)
            }
            .navigationTitle("Crochet Chart")
            .navigationDestination(isPresented: $showChart) {
                if let pattern = parsedPattern {
                    ChartDetailView(pattern: pattern, showRowNumbers: showRowNumbers)
                }
            }
        }
    }
}

// MARK: - Chart Detail View

struct ChartDetailView: View {
    let pattern: ParsedPattern
    let showRowNumbers: Bool
    @State private var showLegend = false
    @State private var isSharing = false
    @State private var isRoundMode = false   // NEW — toggle between row grid and round chart

    private var allStitches: [Stitch] { pattern.rows.flatMap(\.stitches) }

    // Heuristic: if any row prefix was Rnd/Round, default to round mode
    private var isLikelyRound: Bool {
        pattern.rows.first?.rawText.lowercased().hasPrefix("rnd") == true ||
        pattern.rows.first?.rawText.lowercased().hasPrefix("round") == true ||
        pattern.rows.first?.rawText.lowercased().hasPrefix("r") == true
    }

    var body: some View {
        VStack(spacing: 0) {
            if pattern.rows.isEmpty {
                ContentUnavailableView(
                    "No rows detected",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Make sure lines start with Row, Rnd, or Round.")
                )
            } else if isRoundMode {
                // ROUND/SQUARE CHART
                RoundChartContainerView(pattern: pattern)
            } else {
                // LINEAR ROW GRID
                ChartView(pattern: pattern, showRowNumbers: showRowNumbers)
            }

            if showLegend {
                Divider()
                LegendView(stitches: allStitches)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(pattern.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isRoundMode = isLikelyRound }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Chart type toggle
                Button {
                    withAnimation(.spring(response: 0.3)) { isRoundMode.toggle() }
                } label: {
                    Image(systemName: isRoundMode ? "square.on.square.fill" : "square.on.square")
                }
                .help(isRoundMode ? "Switch to row grid" : "Switch to round chart")

                // Legend toggle
                Button {
                    withAnimation(.spring(response: 0.3)) { showLegend.toggle() }
                } label: {
                    Image(systemName: showLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                }

                // Share
                Button { isSharing = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(items: [buildShareText()])
        }
    }

    private func buildShareText() -> String {
        var lines = [pattern.title, ""]
        for row in pattern.rows {
            let symbols = row.stitches.map(\.symbol).joined()
            let count = row.stitchCount.map { " (\($0))" } ?? ""
            lines.append("Rnd \(row.rowNumber): \(symbols)\(count)")
        }
        lines.append("")
        lines.append("Legend:")
        var seen: Set<String> = []
        for stitch in allStitches {
            if seen.insert(stitch.shortName).inserted {
                lines.append("  \(stitch.symbol) = \(stitch.fullName) (\(stitch.shortName.uppercased()))")
            }
        }
        return lines.joined(separator: "\n")
    }
}


// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - App Entry Point

@main
struct CrochetChartApp: App {
    var body: some Scene {
        WindowGroup {
            PatternInputView()
        }
    }
}
