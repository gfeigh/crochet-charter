import Foundation

// MARK: - Round shape

enum RoundShape {
    case center    // magic ring / starting round
    case square    // exactly 4 parenthetical corner groups detected
    case circular  // no corners — smooth ring
}

// MARK: - Stitch token

struct StitchToken: Equatable {
    let stitch: Stitch
    let isCorner: Bool   // part of a (…) corner group
}

// MARK: - One parsed round

struct PatternRound: Identifiable {
    let id = UUID()
    let roundNumber: Int
    let shape: RoundShape
    let tokens: [StitchToken]
    let rawText: String
    let declaredCount: Int?

    var stitches: [Stitch] { tokens.map(\.stitch) }
}

// MARK: - Full parsed pattern

struct ParsedPattern {
    let title: String
    let rounds: [PatternRound]
    var allStitches: [Stitch] { rounds.flatMap(\.stitches) }
}

// MARK: - Parser

struct PatternParser {

    // Stitch keyword table — longest first to avoid partial matches
    private static let stitchKeywords: [(keywords: [String], stitch: Stitch)] = [
        (["sl st", "slip st", "slipstitch", "slip stitch"], .slipStitch),
        (["sc2tog", "sc 2 tog"],                            .decrease),
        (["hdc"],                                           .halfDoubleCrochet),
        (["dc"],                                            .doubleCrochet),
        (["tr", "trc"],                                     .trebleCrochet),
        (["mr", "magic ring", "magic circle"],              .magicRing),
        (["inc", "increase"],                               .increase),
        (["dec", "decrease"],                               .decrease),
        (["sc"],                                            .singleCrochet),
        (["ch", "chain"],                                   .chainStitch),
    ]

    private static let skipWords = Set([
        "in","from","hook","st","sts","to","of","the","each",
        "sp","ch-sp","space","join","at","with","across","around",
        "times","counts","as","top","next","same","into"
    ])

    // MARK: - Public API

    func parse(text: String) -> ParsedPattern {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var title = "Granny Square"
        var start = 0

        if let first = lines.first {
            let l = first.lowercased()
            let isRound = l.hasPrefix("rnd") || l.hasPrefix("round") ||
                          l.hasPrefix("row") ||
                          (l.hasPrefix("r") && l.count > 1 && l.dropFirst().first?.isNumber == true)
            if !isRound { title = first; start = 1 }
        }

        var rounds: [PatternRound] = []
        var counter = 1
        for line in lines[start...] {
            if let r = parseLine(line, fallback: counter) {
                rounds.append(r)
                counter = r.roundNumber + 1
            }
        }
        return ParsedPattern(title: title, rounds: rounds)
    }

    // MARK: - Line → PatternRound

    private func parseLine(_ line: String, fallback: Int) -> PatternRound? {
        let lower = line.lowercased()
        let isRoundLine = lower.hasPrefix("rnd") || lower.hasPrefix("round") ||
                          lower.hasPrefix("row") ||
                          (lower.hasPrefix("r") && lower.count > 1 &&
                           lower.dropFirst().first?.isNumber == true)
        guard isRoundLine else { return nil }

        let number = extractRoundNumber(from: lower) ?? fallback
        let declared = extractDeclaredCount(from: line)
        let instructions = stripRoundPrefix(from: lower)

        let isMR = instructions.contains("magic ring") || instructions.contains("magic circle") ||
                   instructions.contains(" mr,") || instructions.hasPrefix("mr") ||
                   instructions.contains("magic")
        if isMR {
            let tokens = expandInstructions(instructions, isCenter: true)
            return PatternRound(roundNumber: number, shape: .center,
                                tokens: tokens, rawText: line, declaredCount: declared)
        }

        let tokens = expandInstructions(instructions, isCenter: false)
        let cornerCount = countCornerGroups(in: tokens)
        let shape: RoundShape = cornerCount == 4 ? .square : .circular
        return PatternRound(roundNumber: number, shape: shape,
                            tokens: tokens, rawText: line, declaredCount: declared)
    }

    // MARK: - Corner counting

    /// Count how many isCorner=true runs exist (each contiguous run = one corner group).
    private func countCornerGroups(in tokens: [StitchToken]) -> Int {
        var count = 0
        var inCorner = false
        for t in tokens {
            if t.isCorner && !inCorner { count += 1; inCorner = true }
            else if !t.isCorner { inCorner = false }
        }
        return count
    }

    // MARK: - Instruction expansion
    //
    // Pipeline:
    //   raw string
    //     → lex into segments (plain text | (group) | [block] × N)
    //     → expand [block] × N into N copies
    //     → for each segment: if (group) ≤7 stitches with corner pattern → mark isCorner
    //                         else expand normally

    private func expandInstructions(_ text: String, isCenter: Bool) -> [StitchToken] {
        let segments = lex(text)
        var result: [StitchToken] = []

        for seg in segments {
            switch seg {
            case .plain(let s):
                result += expandPlain(s, isCorner: false)

            case .group(let inner):
                // (…) — potential corner group.
                // Corner check uses written CLAUSES (≤7 terms), not expanded stitch count.
                // e.g. "(3 dc, ch 3, 3 dc)" = 3 clauses → corner ✓ even though it expands to 9 stitches.
                let stitches = stitchesFromPlain(inner)
                let isCorner = !isCenter && hasCornerPatternInClauses(inner)
                result += stitches.map { StitchToken(stitch: $0, isCorner: isCorner) }

            case .repeat(let inner, let times):
                // [… ] × N — expand the inner content N times
                let innerSegs = lex(inner)
                for _ in 0..<times {
                    for innerSeg in innerSegs {
                        switch innerSeg {
                        case .plain(let s):
                            result += expandPlain(s, isCorner: false)
                        case .group(let g):
                            let stitches = stitchesFromPlain(g)
                            let isCorner = !isCenter && hasCornerPatternInClauses(g)
                            result += stitches.map { StitchToken(stitch: $0, isCorner: isCorner) }
                        case .repeat(let inner2, let times2):
                            // nested repeat — expand recursively
                            let inner2Tokens = expandInstructions(inner2, isCenter: isCenter)
                            for _ in 0..<times2 { result += inner2Tokens }
                        }
                    }
                }
            }
        }
        return result
    }

    // MARK: - Lexer
    //
    // Produces a flat list of segments from the instruction string.
    // Handles:
    //   (group)          — parenthetical stitch cluster
    //   [block] x N      — bracketed repeat with count
    //   plain text       — comma-separated stitch clauses

    private enum Segment {
        case plain(String)
        case group(String)         // content inside (…)
        case `repeat`(String, Int) // content inside […], repeat count
    }

    private func lex(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var i = text.startIndex
        var plainAccum = ""

        while i < text.endIndex {
            let ch = text[i]

            if ch == "(" {
                // Flush plain accumulator
                if !plainAccum.trimmingCharacters(in: .whitespaces).isEmpty {
                    segments.append(.plain(plainAccum))
                }
                plainAccum = ""
                // Find matching closing paren
                if let close = findClosing(text, open: "(", close: ")", from: text.index(after: i)) {
                    let inner = String(text[text.index(after: i)..<close])
                    segments.append(.group(inner))
                    i = text.index(after: close)
                } else {
                    plainAccum.append(ch)
                    i = text.index(after: i)
                }

            } else if ch == "[" {
                if !plainAccum.trimmingCharacters(in: .whitespaces).isEmpty {
                    segments.append(.plain(plainAccum))
                }
                plainAccum = ""
                if let close = findClosing(text, open: "[", close: "]", from: text.index(after: i)) {
                    let inner = String(text[text.index(after: i)..<close])
                    let afterClose = text.index(after: close)
                    let repeatCount = parseRepeatCount(text, from: afterClose)
                    segments.append(.repeat(inner, repeatCount.count))
                    i = repeatCount.end
                } else {
                    plainAccum.append(ch)
                    i = text.index(after: i)
                }

            } else {
                plainAccum.append(ch)
                i = text.index(after: i)
            }
        }

        if !plainAccum.trimmingCharacters(in: .whitespaces).isEmpty {
            segments.append(.plain(plainAccum))
        }
        return segments
    }

    /// Find the matching closing bracket/paren, respecting nesting.
    private func findClosing(_ text: String, open: Character, close: Character,
                              from start: String.Index) -> String.Index? {
        var depth = 1
        var i = start
        while i < text.endIndex {
            if text[i] == open { depth += 1 }
            else if text[i] == close {
                depth -= 1
                if depth == 0 { return i }
            }
            i = text.index(after: i)
        }
        return nil
    }

    /// Parse a repeat count suffix like "x 4", "× 4", "4 times", "times 4" after a ]
    private func parseRepeatCount(_ text: String, from start: String.Index) -> (count: Int, end: String.Index) {
        var i = start
        // Skip whitespace
        while i < text.endIndex && text[i].isWhitespace { i = text.index(after: i) }

        let remaining = String(text[i...]).lowercased()

        // Patterns: "x 3", "×3", "* 3", "3 times", "times 3", "(3 times)", "3x"
        let patterns: [(pattern: String, numGroup: Int)] = [
            (#"^[x×\*]\s*(\d+)"#, 1),
            (#"^(\d+)\s*[x×]"#, 1),
            (#"^(\d+)\s+times"#, 1),
            (#"^times\s+(\d+)"#, 1),
            (#"^\((\d+)\s+times\)"#, 1),
        ]

        for (pattern, group) in patterns {
            if let rx = try? NSRegularExpression(pattern: pattern),
               let m = rx.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
               let nr = Range(m.range(at: group), in: remaining),
               let n = Int(remaining[nr]) {
                // Advance i past the matched portion
                let matchLen = m.range.length
                var end = i
                var advance = 0
                while advance < matchLen && end < text.endIndex {
                    end = text.index(after: end)
                    advance += 1
                }
                return (n, end)
            }
        }

        return (1, start) // no repeat found — treat as ×1
    }

    // MARK: - Corner detection
    //
    // A (group) is a corner if:
    //   1. It has ≤ 7 written CLAUSES (e.g. "3 dc, ch 3, 3 dc" = 3 clauses — not 9 expanded stitches)
    //   2. Its clause stitch-types match:  [post]+ [chain]+ [post]+
    //      where post = dc, hdc, or tr
    //
    // Counting clauses rather than expanded stitches means "(3 dc, ch 3, 3 dc)" (3 clauses, 9 stitches)
    // and "(2 dc, ch 2, 2 dc)" (3 clauses, 6 stitches) are both correctly detected as corners,
    // while an 8-clause group like "(dc, ch 1, dc, ch 1, dc, ch 1, dc, ch 1)" is rejected.

    private func hasCornerPatternInClauses(_ inner: String) -> Bool {
        let clauses = inner
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard (3...7).contains(clauses.count) else { return false }

        // Get the stitch TYPE for each clause (ignoring the repeat count)
        let types = clauses.compactMap { parseClause($0).0 }
        guard !types.isEmpty else { return false }

        var i = 0
        // Leading posts
        guard isPost(types[i]) else { return false }
        while i < types.count && isPost(types[i]) { i += 1 }
        // Chains
        guard i < types.count, types[i] == .chainStitch else { return false }
        while i < types.count && types[i] == .chainStitch { i += 1 }
        // Trailing posts
        guard i < types.count, isPost(types[i]) else { return false }
        return true
    }

    private func isPost(_ s: Stitch) -> Bool {
        s == .doubleCrochet || s == .trebleCrochet || s == .halfDoubleCrochet
    }

    // MARK: - Plain text → [Stitch]

    private func stitchesFromPlain(_ text: String) -> [Stitch] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { clause -> [Stitch] in
                let (stitch, count) = parseClause(clause)
                guard let s = stitch else { return [] }
                return Array(repeating: s, count: max(1, count))
            }
    }

    private func expandPlain(_ text: String, isCorner: Bool) -> [StitchToken] {
        stitchesFromPlain(text).map { StitchToken(stitch: $0, isCorner: isCorner) }
    }

    // MARK: - Clause parsing ("3 dc", "dc 3", "dc")

    private func parseClause(_ text: String) -> (Stitch?, Int) {
        let t = text.trimmingCharacters(in: .whitespaces)
        // "N stitch"
        if let rx = try? NSRegularExpression(pattern: #"^(\d+)\s+(.+)$"#),
           let m = rx.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
           let cr = Range(m.range(at: 1), in: t), let sr = Range(m.range(at: 2), in: t) {
            return (matchStitch(String(t[sr])), Int(t[cr]) ?? 1)
        }
        // "stitch N"
        if let rx = try? NSRegularExpression(pattern: #"^(.+?)\s+(\d+)$"#),
           let m = rx.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
           let sr = Range(m.range(at: 1), in: t), let cr = Range(m.range(at: 2), in: t) {
            return (matchStitch(String(t[sr])), Int(t[cr]) ?? 1)
        }
        return (matchStitch(t), 1)
    }

    private func matchStitch(_ raw: String) -> Stitch? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !PatternParser.skipWords.contains(t) else { return nil }
        for entry in PatternParser.stitchKeywords {
            for kw in entry.keywords {
                if t == kw || t.hasPrefix(kw + " ") || t.hasSuffix(" " + kw) || t.contains(" \(kw) ") {
                    return entry.stitch
                }
            }
        }
        for entry in PatternParser.stitchKeywords {
            for kw in entry.keywords where t.contains(kw) { return entry.stitch }
        }
        return .unknown(t)
    }

    // MARK: - Utility helpers

    private func extractRoundNumber(from lower: String) -> Int? {
        let pats = [#"rnd\s*(\d+)"#, #"round\s*(\d+)"#, #"row\s*(\d+)"#, #"^r(\d+)"#]
        for p in pats {
            if let rx = try? NSRegularExpression(pattern: p),
               let m = rx.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
               let r = Range(m.range(at: 1), in: lower) { return Int(lower[r]) }
        }
        return nil
    }

    private func stripRoundPrefix(from text: String) -> String {
        let pats = [#"^rnd\s*\d+[:\-\s]*"#, #"^round\s*\d+[:\-\s]*"#,
                    #"^row\s*\d+[:\-\s]*"#,  #"^r\d+[:\-\s]*"#]
        var s = text
        for p in pats {
            if let rx = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s),
                                                withTemplate: "")
            }
        }
        // Strip trailing stitch count "(12 sts)" or "(12)"
        if let rx = try? NSRegularExpression(pattern: #"\(\d+\s*sts?\)\s*$"#) {
            s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s),
                                            withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private func extractDeclaredCount(from text: String) -> Int? {
        let pats = [#"\((\d+)\s*sts?\)"#, #"\((\d+)\)\s*$"#]
        for p in pats {
            if let rx = try? NSRegularExpression(pattern: p),
               let m = rx.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(m.range(at: 1), in: text) { return Int(text[r]) }
        }
        return nil
    }
}
