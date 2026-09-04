import Foundation
import Testing
@testable import RPGFitMVP

struct PlatformSafetyRegressionTests {
    @Test func plateMathRejectsAPlateCountOutsideIntRange() {
        let solution = PlateMath.solve(
            target: 1e300,
            bar: 20,
            plates: PlateMath.standardPlates(kg: true)
        )

        #expect(solution == nil)
    }

    @Test func plateMathRejectsInvalidPlateDenominations() {
        #expect(PlateMath.solve(target: 100, bar: 20, plates: [20, 0]) == nil)
        #expect(PlateMath.solve(target: 100, bar: 20, plates: [20, .infinity]) == nil)
    }
}
