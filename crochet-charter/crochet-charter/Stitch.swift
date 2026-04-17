import SwiftUI

// MARK: - Stitch Types

enum Stitch: Equatable {
    case chainStitch          // ch
    case slipStitch           // sl st
    case singleCrochet        // sc
    case halfDoubleCrochet    // hdc
    case doubleCrochet        // dc
    case trebleCrochet        // tr
    case magicRing            // mr
    case increase             // inc
    case decrease             // dec
    case unknown(String)

    var symbol: String {
        switch self {
        case .chainStitch:        return "○"
        case .slipStitch:         return "•"
        case .singleCrochet:      return "+"
        case .halfDoubleCrochet:  return "T"
        case .doubleCrochet:      return "⊤"
        case .trebleCrochet:      return "⤒"
        case .magicRing:          return "⊗"
        case .increase:           return "⋀"
        case .decrease:           return "⋁"
        case .unknown:            return "?"
        }
    }

    var shortName: String {
        switch self {
        case .chainStitch:        return "ch"
        case .slipStitch:         return "sl st"
        case .singleCrochet:      return "sc"
        case .halfDoubleCrochet:  return "hdc"
        case .doubleCrochet:      return "dc"
        case .trebleCrochet:      return "tr"
        case .magicRing:          return "mr"
        case .increase:           return "inc"
        case .decrease:           return "dec"
        case .unknown(let s):     return s
        }
    }

    var fullName: String {
        switch self {
        case .chainStitch:        return "Chain stitch"
        case .slipStitch:         return "Slip stitch"
        case .singleCrochet:      return "Single crochet"
        case .halfDoubleCrochet:  return "Half double crochet"
        case .doubleCrochet:      return "Double crochet"
        case .trebleCrochet:      return "Treble crochet"
        case .magicRing:          return "Magic ring"
        case .increase:           return "Increase"
        case .decrease:           return "Decrease"
        case .unknown(let s):     return s
        }
    }

    var color: Color {
        switch self {
        case .chainStitch:        return Color(.systemGray)
        case .slipStitch:         return Color(.systemGray2)
        case .singleCrochet:      return Color(.systemBlue)
        case .halfDoubleCrochet:  return Color(.systemTeal)
        case .doubleCrochet:      return Color(.systemPurple)
        case .trebleCrochet:      return Color(.systemIndigo)
        case .magicRing:          return Color(.systemOrange)
        case .increase:           return Color(.systemGreen)
        case .decrease:           return Color(.systemRed)
        case .unknown:            return Color(.systemYellow)
        }
    }
}
