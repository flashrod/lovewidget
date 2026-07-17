import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("Invite Code Generator")
struct InviteCodeTests {

    @Test("Generated code has correct format")
    func generatedFormat() {
        for _ in 0..<100 {
            let code = InviteCodeGenerator.generate()
            #expect(code.count == 8, "Expected 'XXX-XXXX' format")
            let parts = code.split(separator: "-")
            #expect(parts.count == 2)
            #expect(parts[0].count == 3)
            #expect(parts[1].count == 4)
        }
    }

    @Test("Generated code contains only valid characters")
    func generatedCharacters() {
        let valid = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789-")
        for _ in 0..<50 {
            let code = InviteCodeGenerator.generate()
            #expect(Set(code).isSubset(of: valid))
        }
    }

    @Test("Generated codes are unique")
    func generatedUnique() {
        var seen = Set<String>()
        for _ in 0..<1000 {
            let code = InviteCodeGenerator.generate()
            #expect(!seen.contains(code))
            seen.insert(code)
        }
    }

    // MARK: - Validation

    @Test("Valid code passes validation")
    func validCode() {
        #expect(InviteCodeGenerator.isValid("ABF-3R7K") == true)
        #expect(InviteCodeGenerator.isValid("XYZ-2345") == true)
        #expect(InviteCodeGenerator.isValid("ABC-DEFG") == true)
    }

    @Test("Invalid code fails validation")
    func invalidCode() {
        #expect(InviteCodeGenerator.isValid("") == false)
        #expect(InviteCodeGenerator.isValid("AB") == false)
        #expect(InviteCodeGenerator.isValid("ABCD-EFGH") == false)
        #expect(InviteCodeGenerator.isValid("AB-3R7K") == false)
        #expect(InviteCodeGenerator.isValid("ABC-3R7") == false)
        #expect(InviteCodeGenerator.isValid("ABC-3R7KK") == false)
    }

    @Test("Code with ambiguous characters fails")
    func ambiguousCharacters() {
        // Codes containing 0, O, 1, I, L should not be generated
        // but if manually entered, they should fail validation
        #expect(InviteCodeGenerator.isValid("ABO-3R7K") == false)
        #expect(InviteCodeGenerator.isValid("AB0-3R7K") == false)
        #expect(InviteCodeGenerator.isValid("ABI-3R7K") == false)
        #expect(InviteCodeGenerator.isValid("ABL-3R7K") == false)
        #expect(InviteCodeGenerator.isValid("AB1-3R7K") == false)
    }

    // MARK: - Normalization

    @Test("Lowercase normalization")
    func normalizationLowercase() {
        #expect(InviteCodeGenerator.normalize("abf-3r7k") == "ABF-3R7K")
    }

    @Test("Normalization strips spaces")
    func normalizationStripsSpaces() {
        #expect(InviteCodeGenerator.normalize(" ABF-3R7K ") == "ABF-3R7K")
    }

    @Test("Normalization adds missing dash")
    func normalizationAddsDash() {
        #expect(InviteCodeGenerator.normalize("ABF3R7K") == "ABF-3R7K")
    }

    @Test("Normalization handles extra dashes")
    func normalizationExtraDashes() {
        #expect(InviteCodeGenerator.normalize("--ABF-3R7K--") == "ABF-3R7K")
    }

    @Test("Normalization handles non-alphanumeric")
    func normalizationNonAlphanumeric() {
        #expect(InviteCodeGenerator.normalize("ABF-3R7K!@#") == "ABF-3R7K")
    }

    @Test("Normalization short input unchanged")
    func normalizationShortInput() {
        // Too short to be valid, should return stripped
        let result = InviteCodeGenerator.normalize("AB")
        #expect(result == "AB")
    }
}
