import SwiftUI

// MARK: - Pattern Input

struct PatternInputView: View {
    @State private var patternText = ""
    @State private var parsedPattern: ParsedPattern?
    @State private var showChart = false
    @FocusState private var editorFocused: Bool

    private let parser = PatternParser()

    // A classic 3-round granny square
    private let example = """
    Classic Granny Square
    Rnd 1: Magic ring, ch 3 (counts as dc), 11 dc (12 dc)
    Rnd 2: sl st to ch-2 sp, ch 3, dc in same stitch, (2 dc) 11 times (24 dc)
    Rnd 3: sl st to ch-2 sp, ch 3, dc, (2dc, dc) 11 times, sl st (36 dc)
    Rnd 4: (2 dc, ch 3, dc 2), 8 dc, (2 dc, ch 3, 2 dc), 8 dc, (2 dc, ch 3, 2 dc), 8 dc, (2 dc, ch 3, 2 dc), 8 dc
    """

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pattern text editor
                ZStack(alignment: .topLeading) {
                    if patternText.isEmpty {
                        Text("Paste your granny square pattern here…\n\nExample format:\nRnd 1: Magic ring, ch 3, 2 dc, ch 2, (3 dc, ch 2) 3 times, sl st\nRnd 2: sl st, ch 3, 2 dc, ch 2, 3 dc, ch 1, (3 dc, ch 2, 3 dc, ch 1) 3 times, sl st")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $patternText)
                        .font(.system(.body, design: .monospaced))
                        .focused($editorFocused)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()

                // Round classification preview
                if !patternText.isEmpty {
                    roundPreview
                }

                // Action buttons
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button {
                            patternText = example
                            editorFocused = false
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
                        editorFocused = false
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
            .navigationTitle("Granny Square Chart")
            .navigationDestination(isPresented: $showChart) {
                if let pattern = parsedPattern {
                    GrannyChartView(pattern: pattern)
                }
            }
        }
    }

    // Shows each detected round's shape classification
    @ViewBuilder
    private var roundPreview: some View {
        let pattern = parser.parse(text: patternText)
        if !pattern.rounds.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pattern.rounds) { round in
                        VStack(spacing: 2) {
                            Image(systemName: shapeIcon(round.shape))
                                .font(.system(size: 14))
                                .foregroundColor(shapeColor(round.shape))
                            Text("Rnd \(round.roundNumber)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text(shapeLabel(round.shape))
                                .font(.system(size: 9))
                                .foregroundColor(shapeColor(round.shape))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(shapeColor(round.shape).opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }

    private func shapeIcon(_ shape: RoundShape) -> String {
        switch shape {
        case .center:   return "scope"
        case .square:   return "square"
        case .circular: return "circle"
        }
    }
    private func shapeLabel(_ shape: RoundShape) -> String {
        switch shape {
        case .center:   return "center"
        case .square:   return "square"
        case .circular: return "round"
        }
    }
    private func shapeColor(_ shape: RoundShape) -> Color {
        switch shape {
        case .center:   return .orange
        case .square:   return Color(.systemIndigo)
        case .circular: return .teal
        }
    }
}

// MARK: - App entry point

@main
struct CrochetChartApp: App {
    var body: some Scene {
        WindowGroup {
            PatternInputView()
        }
    }
}
