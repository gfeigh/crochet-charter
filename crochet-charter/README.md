# Crochet Chart – iOS App

Convert written crochet patterns into visual stitch charts.

## Files

| File | Purpose |
|---|---|
| `Stitch.swift` | Stitch enum with symbols, colours, names |
| `PatternParser.swift` | Tokeniser that reads row text into `[Stitch]` arrays |
| `ChartViews.swift` | `StitchCell`, `ChartRowView`, `ChartView`, `LegendView` |
| `ContentView.swift` | Input screen, chart detail, share sheet, `@main` |

## How to set up in Xcode

1. Open Xcode → **File → New → Project** → App
2. Product name: `CrochetChart`, Interface: SwiftUI, Language: Swift
3. Delete the default `ContentView.swift`
4. Drag all four `.swift` files into the project navigator
5. Make sure all files have **Target Membership** checked for your app target
6. Press **Run** (⌘R)

## Supported pattern formats

The parser understands most common abbreviations:

| Abbrev | Stitch |
|---|---|
| `ch` | Chain stitch |
| `sl st` | Slip stitch |
| `sc` | Single crochet |
| `hdc` | Half double crochet |
| `dc` | Double crochet |
| `tr` / `trc` | Treble crochet |
| `mr` / `magic ring` | Magic ring |
| `inc` | Increase |
| `dec` / `sc2tog` | Decrease |

Row prefixes recognised: `Row N:`, `Rnd N:`, `Round N:`, `RN:`

Stitch counts in parentheses are extracted: `(12 sts)`, `(12)`

## Extending the parser

Add new stitches to `PatternParser.stitchKeywords` and the `Stitch` enum.

## Future ideas

- Grid-style square chart (for granny squares / amigurumi rounds)
- Color block sections for colour-work patterns
- Image/PDF export using `ImageRenderer`
- iCloud sync for saved patterns
- CoreData persistence
