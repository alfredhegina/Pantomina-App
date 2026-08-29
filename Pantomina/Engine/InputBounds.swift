import Foundation

/// Shared input bounds for names, notes, and money. UI clamps/rejects; does not invent rules.
public enum InputBounds {
    public static let maxDisplayNameLength = 40
    public static let maxPetNameLength = 24
    public static let maxNoteLength = 200
    public static let maxAmountPesos = 100_000_000
    public static let maxAmountC = maxAmountPesos * 100
    public static let minAmountC = 1

    /// Length-only clamp for live typing (no trim).
    public static func limiting(_ raw: String, max: Int) -> String {
        var result = ""
        var count = 0
        for cluster in raw {
            if count >= max { break }
            result.append(cluster)
            count += 1
        }
        return result
    }

    public static func clampDisplayName(_ raw: String) -> String {
        limiting(raw.trimmingCharacters(in: .whitespacesAndNewlines), max: maxDisplayNameLength)
    }

    public static func clampPetName(_ raw: String) -> String {
        limiting(raw.trimmingCharacters(in: .whitespacesAndNewlines), max: maxPetNameLength)
    }

    public static func clampNote(_ raw: String) -> String {
        limiting(raw, max: maxNoteLength)
    }

    public static func isValidAmountC(_ amountC: Int) -> Bool {
        amountC >= minAmountC && amountC <= maxAmountC
    }

    /// Parses a peso decimal string into centavos. Returns nil if unparsable or out of range.
    public static func centavos(fromPesosText text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let pesos = Double(cleaned), pesos.isFinite else { return nil }
        let amountC = Int((pesos * 100).rounded())
        guard isValidAmountC(amountC) else { return nil }
        return amountC
    }
}
