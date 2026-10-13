import Testing
import Foundation
@testable import Evals

@Suite struct EvalSuiteTests {
    @Test func theSuiteIsBigEnoughInEveryCategory() {
        #expect(EvalSuite.cases.count >= 50)
        for category in EvalCategory.allCases {
            #expect(EvalSuite.cases.filter { $0.category == category }.count >= 5, Comment(rawValue: category.rawValue))
        }
    }

    @Test func caseIDsAreUnique() {
        let ids = EvalSuite.cases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyCasePasses() async {
        let report = await EvalSuite.run()
        let text = report.failures.map { "\($0.id): \($0.failure ?? "")" }.joined(separator: "; ")
        #expect(report.failures.isEmpty, Comment(rawValue: text))
        #expect(report.meetsTarget)
    }

    @Test func reportMathIsRight() {
        let rows = [
            EvalResult(id: "a", category: .memory, summary: "", failure: nil),
            EvalResult(id: "b", category: .memory, summary: "", failure: "no"),
            EvalResult(id: "c", category: .refusal, summary: "", failure: nil),
            EvalResult(id: "d", category: .refusal, summary: "", failure: nil),
        ]
        let report = EvalReport(results: rows)
        #expect(report.passedCount == 3 && report.passRate == 0.75 && !report.meetsTarget)
        #expect(report.counts(for: .memory) == (1, 2))
        #expect(report.headline == "3 of 4 passed (75%), target 90%")
        #expect(EvalReport(results: []).passRate == 0)
    }
}
