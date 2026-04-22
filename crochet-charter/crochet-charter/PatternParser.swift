import Foundation

// MARK: - Data Models

struct StitchRow: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let stitches: [Stitch]
    let rawText: String
    let stitchCount: Int?
}

struct ParsedPattern {
    let title: String
    let rows: [StitchRow]
    var stitchesUsed: Set<String> {
        Set(rows.flatMap(\.stitches).map(\.shortName))
    }
}

// MARK: - Pattern Parser

struct PatternParser {

    // Ordered from longest to shortest to avoid partial matches
    private static let stitchKeywords: [(keywords: [String], stitch: Stitch)] = [
        (["sl st", "slip st", "slipstitch", "slip stitch"],    .slipStitch),
        (["hdc"],                                               .halfDoubleCrochet),
        (["dc"],                                                .doubleCrochet),
        (["tr", "trc"],                                         .trebleCrochet),
        (["mr", "magic ring", "magic circle"],                  .magicRing),
        (["inc", "increase"],                                   .increase),
        (["dec", "decrease", "sc2tog", "sc 2 tog"],            .decrease),
        (["sc", "single crochet"],                              .singleCrochet),
        (["ch", "chain"],                                       .chainStitch),
    ]

    func parse(text: String) -> ParsedPattern {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var rows: [StitchRow] = []
        var rowCounter = 1

        // Try to detect a title (first non-row line)
        var title = "My Pattern"
        var startIndex = 0

        if let firstLine = lines.first {
            let lower = firstLine.lowercased()
            let isRow = lower.hasPrefix("row") || lower.hasPrefix("rnd") || lower.hasPrefix("round")
            if !isRow {
                title = firstLine
                startIndex = 1
            }
        }

        for i in startIndex..<lines.count {
            let line = lines[i]
            let lower = line.lowercased()

            // Detect row/round markers
            let isRow = lower.hasPrefix("row") || lower.hasPrefix("rnd") ||
                        lower.hasPrefix("round") || lower.hasPrefix("r")

            // Extract a row number if present
            let detectedNumber = extractRowNumber(from: lower) ?? rowCounter

            // Strip the "Row N:" prefix to get the stitch instructions
            let instructions = stripRowPrefix(from: line)
            var stitches = parseStitches(from: instructions)

            // Extract stitch count from parentheses e.g. (12 sts)
            let count = extractStitchCount(from: line)

            if !stitches.isEmpty || isRow {
                //catch MR as first row in circular patterns
                if stitches.first?.shortName == "mr"{
                    let mr:[Stitch] = [stitches.first!]
                    stitches.removeFirst()
                    rows.append(StitchRow(
                        rowNumber: detectedNumber,
                        stitches: mr,
                        rawText: line,
                        stitchCount: count
                    ))
                    rowCounter = detectedNumber + 1
                }
                rows.append(StitchRow(
                    rowNumber: rowCounter,
                    stitches: stitches,
                    rawText: line,
                    stitchCount: count
                ))
                rowCounter = rowCounter + 1
            }
        }

        return ParsedPattern(title: title, rows: rows)
    }

    // MARK: - Helpers

    private func extractRowNumber(from text: String) -> Int? {
        let patterns = ["row\\s*(\\d+)", "rnd\\s*(\\d+)", "round\\s*(\\d+)", "^r(\\d+)"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        }
        return nil
    }

    private func stripRowPrefix(from line: String) -> String {
        // Remove "Row 1:", "Rnd 2:", "Round 3:", "R4:" etc.
        let patterns = ["^row\\s*\\d+[:\\-\\s]*", "^rnd\\s*\\d+[:\\-\\s]*",
                        "^round\\s*\\d+[:\\-\\s]*", "^r\\d+[:\\-\\s]*"]
        var result = line.lowercased()
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }
        return result
    }

    private func extractStitchCount(from text: String) -> Int? {
        // Match (12 sts) or (12) at end of line
        let patterns = ["\\((\\d+)\\s*sts?\\)", "\\((\\d+)\\)\\s*$"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        }
        return nil
    }

    func parseStitches(from instructions: String) -> [Stitch] {
        var result: [Stitch] = []
        var remaining = instructions.lowercased()
        
        //split on Parantheticals for repeating clauses
        let pattern = /\[.*?\]|\(.*?\)|[^\[\]()]+/
        let matches = remaining.matches(of: pattern)
        let repetitions = matches.map { String($0.output) }
        for (ri,repetition) in repetitions.enumerated(){
            // Split on commas, semicolons for clause separation
            let trimmedRep = repetition.trimmingCharacters(in: .whitespaces)
            if trimmedRep.hasPrefix("counts") || trimmedRep.hasSuffix("sts") || isRepeatClause(from: trimmedRep){
                continue
            }
            //default repeat - none
            var repeatClause = 1
            //check for repeat instruction after clause
            if repetitions.indices.contains(ri+1){
                    let futureClauses = repetitions[ri+1].components(separatedBy: CharacterSet(charactersIn: ",;"))
                    let firstClause = futureClauses[0]
                    let trimmedClause = firstClause.trimmingCharacters(in: .whitespaces)
                    if isRepeatClause(from: trimmedClause){
                        let clauseWords = trimmedClause.components(separatedBy: " ")
                    for word in clauseWords{
                            if Int(word) != nil{
                                repeatClause = Int(word) ?? 1
                                print("repeating Clause : \(repeatClause)")
                            }
                        }
                    }
            }
            // catch clauses in parenthesis without repeat instructions (worked into one stitch)
            var clauses:[String] = [String(trimmedRep)]
            print(repetition)
            if !repetition.hasPrefix("("){
                print("not same stitch")
                clauses = repetition.components(separatedBy: CharacterSet(charactersIn: ",;"))
            }
            for _ in 1...repeatClause{
                for clause in clauses {
                    let trimmed = clause.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    guard !isRepeatClause(from: trimmed) else { continue }
                    // Try to extract a repeat count before the stitch: e.g. "sc 5", "3 dc"
                    let (stitch, count) = extractStitchAndCount(from: trimmed)
                    
                    if let s = stitch {
                        for _ in 0..<max(1, count) {
                            result.append(s)
                        }
                    }
                }
            }
        }

        return result
    }
    
    private func isRepeatClause(from text:String) -> Bool{
        if text.hasPrefix("times ") || text.hasPrefix("x ") || text.hasSuffix("times") || text.hasSuffix(" x"){
            return true
        }
        return false
    }

    private func extractStitchAndCount(from text: String) -> (Stitch?, Int) {
        // Try "N stitch" (count before)
        let countBeforePattern = "^(\\d+)\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: countBeforePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let countRange = Range(match.range(at: 1), in: text),
           let stitchRange = Range(match.range(at: 2), in: text) {
            let count = Int(text[countRange]) ?? 1
            let stitchText = String(text[stitchRange])
            return (matchStitch(in: stitchText), count)
        }

        // Try "stitch N" (count after)
        let countAfterPattern = "^(.+?)\\s+(\\d+)$"
        if let regex = try? NSRegularExpression(pattern: countAfterPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let stitchRange = Range(match.range(at: 1), in: text),
           let countRange = Range(match.range(at: 2), in: text) {
            let count = Int(text[countRange]) ?? 1
            let stitchText = String(text[stitchRange])
            return (matchStitch(in: stitchText), count)
        }

        return (matchStitch(in: text), 1)
    }

    private func matchStitch(in text: String) -> Stitch? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for entry in PatternParser.stitchKeywords {
            for keyword in entry.keywords {
                if trimmed == keyword || trimmed.hasPrefix(keyword + " ") || trimmed.hasSuffix(" " + keyword) || trimmed.contains(" " + keyword + " ") {
                    return entry.stitch
                }
            }
        }
        // Partial match fallback
        for entry in PatternParser.stitchKeywords {
            for keyword in entry.keywords {
                if trimmed.contains(keyword) {
                    return entry.stitch
                }
            }
        }
        if !trimmed.isEmpty && trimmed != "in" && trimmed != "from" && trimmed != "hook" && trimmed != "st" && trimmed != "sts" {
            return .unknown(trimmed)
        }
        return nil
    }
    
}
