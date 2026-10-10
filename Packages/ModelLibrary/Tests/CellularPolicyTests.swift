import Testing
@testable import ModelLibrary

@Suite struct CellularPolicyTests {
    @Test func cellularAndHotspotWarn() {
        #expect(CellularPolicy.needsWarning(isExpensive: true, isConstrained: false, remainingBytes: 700_000_000))
    }

    @Test func lowDataModeWarns() {
        #expect(CellularPolicy.needsWarning(isExpensive: false, isConstrained: true, remainingBytes: 700_000_000))
    }

    @Test func wifiDoesNotWarn() {
        #expect(!CellularPolicy.needsWarning(isExpensive: false, isConstrained: false, remainingBytes: 700_000_000))
    }

    @Test func nothingLeftDoesNotWarn() {
        #expect(!CellularPolicy.needsWarning(isExpensive: true, isConstrained: true, remainingBytes: 0))
    }

    @Test func remainingFollowsProgress() {
        #expect(CellularPolicy.remainingBytes(sizeBytes: 1000, fraction: 0) == 1000)
        #expect(CellularPolicy.remainingBytes(sizeBytes: 1000, fraction: 0.25) == 750)
        #expect(CellularPolicy.remainingBytes(sizeBytes: 1000, fraction: 1) == 0)
        #expect(CellularPolicy.remainingBytes(sizeBytes: 1000, fraction: 3) == 0)
        #expect(CellularPolicy.remainingBytes(sizeBytes: 1000, fraction: -1) == 1000)
    }
}
