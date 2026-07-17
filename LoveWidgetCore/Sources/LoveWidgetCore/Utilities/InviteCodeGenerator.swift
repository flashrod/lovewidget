import Foundation

// MARK: - InviteCodeGenerator

/// Generates and validates short alphanumeric invite codes.
///
/// **Format:** `XXX-XXXX` (7 characters + 1 dash = 8 total)
/// Example: `ABF-3R7K`
///
/// The alphabet excludes visually ambiguous characters:
/// - 0 / O (zero vs letter O)
/// - 1 / I / L (one vs letter I vs letter L)
///
/// This makes manual transcription much easier.
public struct InviteCodeGenerator: Sendable {

    // MARK: - Alphabet

    /// Unambiguous alphanumeric characters for invite codes
    private static let alphabet: [Character] = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    private static let alphabetSet: Set<Character> = Set(alphabet)

    // MARK: - Generation

    /// Generate a fresh random invite code in the format `XXX-XXXX`.
    public static func generate() -> String {
        let prefix = randomSegment(length: 3)
        let suffix  = randomSegment(length: 4)
        return "\(prefix)-\(suffix)"
    }

    private static func randomSegment(length: Int) -> String {
        String((0..<length).compactMap { _ in alphabet.randomElement() })
    }

    // MARK: - Validation

    /// Returns true if `code` is a properly formatted invite code.
    ///
    /// Accepts codes with or without the dash separator, and is case-insensitive.
    public static func isValid(_ code: String) -> Bool {
        let normalized = normalize(code)
        let parts = normalized.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              parts[0].count == 3,
              parts[1].count == 4 else { return false }
        return parts.allSatisfy { part in
            part.allSatisfy { alphabetSet.contains($0) }
        }
    }

    /// Normalize user input into the canonical `XXX-XXXX` format.
    ///
    /// Strips spaces, converts to uppercase, and inserts the dash if absent.
    public static func normalize(_ input: String) -> String {
        let stripped = input
            .uppercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // Already has a dash in the right place
        if stripped.count == 8, stripped[stripped.index(stripped.startIndex, offsetBy: 3)] == "-" {
            return stripped
        }

        // Remove dashes and reformat
        let digits = stripped.filter { $0 != "-" }
        guard digits.count == 7 else { return stripped }
        let prefix = String(digits.prefix(3))
        let suffix  = String(digits.suffix(4))
        return "\(prefix)-\(suffix)"
    }
}
