import Testing
import Foundation
@testable import LoveWidgetCore

@Suite("Pair Model")
struct PairModelTests {

    let userOne = UUID()
    let userTwo = UUID()

    // MARK: - Pair

    @Test("Pair creation")
    func pairCreation() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne)
        #expect(pair.inviteCode == "ABC-1234")
        #expect(pair.userOneID == userOne)
        #expect(pair.userTwoID == nil)
        #expect(!pair.isComplete)
    }

    @Test("Pair completion")
    func pairCompletion() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)
        #expect(pair.isComplete)
    }

    @Test("Pair partnerID for user one")
    func pairPartnerIDForUserOne() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)
        #expect(pair.partnerID(currentUserID: userOne) == userTwo)
    }

    @Test("Pair partnerID for user two")
    func pairPartnerIDForUserTwo() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)
        #expect(pair.partnerID(currentUserID: userTwo) == userOne)
    }

    @Test("Pair partnerID for non-member returns nil")
    func pairPartnerIDForNonMember() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)
        #expect(pair.partnerID(currentUserID: UUID()) == nil)
    }

    @Test("Pair includes user")
    func pairIncludes() {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)
        #expect(pair.includes(userID: userOne))
        #expect(pair.includes(userID: userTwo))
        #expect(!pair.includes(userID: UUID()))
    }

    @Test("Pair Codable round-trip with snake_case keys")
    func pairCodable() throws {
        let pair = Pair(inviteCode: "ABC-1234", userOneID: userOne, userTwoID: userTwo)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pair)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Pair.self, from: data)

        #expect(decoded.inviteCode == pair.inviteCode)
        #expect(decoded.userOneID == pair.userOneID)
        #expect(decoded.userTwoID == pair.userTwoID)
    }

    // MARK: - PairLocalState

    @Test("PairLocalState creation")
    func localStateCreation() {
        let state = PairLocalState(
            pairID: UUID(),
            partnerID: userTwo,
            partnerName: "Bob",
            inviteCode: "ABC-1234"
        )
        #expect(state.isPaired)
        #expect(state.partnerDisplayName == "Bob")
    }

    @Test("PairLocalState unpaired")
    func localStateUnpaired() {
        let state = PairLocalState(
            pairID: UUID(),
            partnerID: nil,
            partnerName: nil,
            inviteCode: "ABC-1234"
        )
        #expect(!state.isPaired)
    }

    @Test("PairLocalState fallback name")
    func localStateFallbackName() {
        let state = PairLocalState(
            pairID: UUID(),
            partnerID: nil,
            partnerName: nil,
            inviteCode: "ABC-1234"
        )
        #expect(state.partnerDisplayName == "Your Partner")
    }
}
