import Foundation

/// Format a numeric price as pence. The input may be either in pounds or already in pence.
/// Heuristic: if the value is >= 1000, treat as pence; otherwise treat as pounds and multiply by 100.
/// The output uses up to 6 decimal places, trimming any trailing zeros.
func formatPencePrice(_ rawValue: Double?) -> String {
    guard let v = rawValue else { return "--" }
    // Determine pence value
    let pence: Double = (v >= 1000.0) ? v : (v * 100.0)

    // Format with up to 6 decimal places then trim trailing zeros
    var s = String(format: "%.6f", pence)
    while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
        s.removeLast()
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
