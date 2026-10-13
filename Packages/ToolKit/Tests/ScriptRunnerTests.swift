import Testing
import Foundation
@testable import ToolKit

@Suite struct ScriptRunnerTests {
    @Test func calculatesAndReadsInput() async {
        let r = await ScriptRunner.run(script: "input.split(',').map(Number).reduce((a,b)=>a+b,0)", input: "1,2,3,4")
        #expect(r == "Script result:\n10")
    }

    @Test func consoleLogAndValueBothShow() async {
        let r = await ScriptRunner.run(script: "console.log('a'); console.log(JSON.stringify({x:1})); 'done'")
        #expect(r == "Script result:\na\n{\"x\":1}\ndone")
    }

    @Test func errorsComeBackAsSentences() async {
        let r = await ScriptRunner.run(script: "nope.x()")
        #expect(r.hasPrefix("Not done: the script failed"))
    }

    @Test func nothingOutsideTheLanguageExists() async {
        let r = await ScriptRunner.run(script: "[typeof fetch, typeof XMLHttpRequest, typeof require, typeof process, typeof setTimeout, typeof window].join(',')")
        #expect(r == "Script result:\nundefined,undefined,undefined,undefined,undefined,undefined")
    }

    @Test func limitsAreEnforced() async {
        #expect(await ScriptRunner.run(script: "  ").hasPrefix("Not done"))
        #expect(await ScriptRunner.run(script: String(repeating: "1;", count: 5000)).hasPrefix("Not done: the script is longer"))
        #expect(await ScriptRunner.run(script: "1", input: String(repeating: "x", count: 200_000)).hasPrefix("Not done: the input is longer"))
        let big = await ScriptRunner.run(script: "'x'.repeat(9000)")
        #expect(big.contains("Cut after") && big.count < 4100)
    }

    @Test func silentScriptSaysSo() async {
        #expect(await ScriptRunner.run(script: "var a = 1;").contains("printed nothing"))
    }
}
