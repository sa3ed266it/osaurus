import Testing

@testable import OsaurusCore

@Suite("Credits rail ring state")
@MainActor
struct CreditsRailRingStateTests {
    @Test func firstPositiveBalanceSetsTheWindowBaseline() {
        let state = CreditsRailRingState()

        state.observe(balanceMicro: "2400000")

        #expect(state.baselineMicro == 2_400_000)
        #expect(state.progress(for: "2400000") == .determinate(1))
        #expect(state.progress(for: "1200000") == .determinate(0.5))
    }

    @Test func nilAndInvalidBalancesDoNotReplaceTheBaselineOrLastObservation() {
        let state = CreditsRailRingState()
        state.observe(balanceMicro: "2400000")

        state.observe(balanceMicro: nil)
        state.observe(balanceMicro: "unavailable")
        state.observe(balanceMicro: "1800000")

        #expect(state.baselineMicro == 2_400_000)
        #expect(state.progress(for: nil) == .indeterminate)
    }

    @Test func zeroIsEmptyAndAReplenishmentResetsTheBaseline() {
        let state = CreditsRailRingState()
        state.observe(balanceMicro: "2400000")

        #expect(state.progress(for: "0") == .empty)
        state.observe(balanceMicro: "0")
        state.observe(balanceMicro: "400000")

        #expect(state.baselineMicro == 400_000)
        #expect(state.progress(for: "400000") == .determinate(1))
    }

    @Test func increaseAfterConsumptionResetsTheBaseline() {
        let state = CreditsRailRingState()
        state.observe(balanceMicro: "2400000")
        state.observe(balanceMicro: "1800000")

        state.observe(balanceMicro: "2000000")

        #expect(state.baselineMicro == 2_000_000)
        #expect(state.progress(for: "2000000") == .determinate(1))
    }

    @Test func eachWindowKeepsAnIndependentBaseline() {
        let firstWindow = CreditsRailRingState()
        let secondWindow = CreditsRailRingState()

        firstWindow.observe(balanceMicro: "2400000")
        secondWindow.observe(balanceMicro: "800000")

        #expect(firstWindow.baselineMicro == 2_400_000)
        #expect(secondWindow.baselineMicro == 800_000)
    }

    @Test func noPositiveBalanceHasAnIndeterminateRing() {
        let state = CreditsRailRingState()

        #expect(state.progress(for: nil) == .indeterminate)
        #expect(state.progress(for: "not-a-balance") == .indeterminate)
        #expect(state.progress(for: "0") == .empty)
        #expect(state.baselineMicro == nil)
    }
}
