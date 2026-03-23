import Foundation

/// Format a price already in pence (GBX) as a display string.
/// API values are always in pence — no conversion applied.
/// Trims trailing zeros after the decimal point.
func formatPencePrice(_ rawValue: Double?) -> String {
    guard let v = rawValue, v > 0 else { return "--" }

    // Format with up to 2 decimal places, trim trailing zeros
    var s = String(format: "%.2f", v)
    if s.contains(".") {
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
    }
    return "\(s)p"
}

extension NumberFormatter {
    static func compact() -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf
    }
}

// Backwards compatibility: keep old name
func formatPenceFromPounds(_ pounds: Double) -> String {
    return formatPencePrice(pounds)
}
