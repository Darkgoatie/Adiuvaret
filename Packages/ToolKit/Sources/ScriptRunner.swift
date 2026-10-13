import Foundation
import JavaScriptCore

/// Runs a short JavaScript snippet in a bare JavaScriptCore context for parsing, converting and calculating.
/// The context has no network, no file access, no timers and no way to reach the app: only the language itself, `input` and `console.log`.
/// It is interpreted by the system's own engine, so no native code is downloaded.
public enum ScriptRunner {
    public static let maxScript = 8000
    public static let maxInput = 100_000
    public static let maxOutput = 4000

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var cont: CheckedContinuation<String, Never>?
        init(_ cont: CheckedContinuation<String, Never>) { self.cont = cont }
        /// True when this call delivered the answer, false when an earlier call already did.
        func finish(_ text: String) -> Bool {
            lock.lock(); let c = cont; cont = nil; lock.unlock()
            guard let c else { return false }
            c.resume(returning: text)
            return true
        }
    }

    private final class LogBox: @unchecked Sendable {
        var lines: [String] = []
        var error: String?
    }

    private static let stuckLock = NSLock()
    nonisolated(unsafe) private static var stuck = false
    private static func setStuck(_ on: Bool) { stuckLock.lock(); stuck = on; stuckLock.unlock() }
    private static func isStuck() -> Bool { stuckLock.lock(); defer { stuckLock.unlock() }; return stuck }

    /// The answer as text. A problem comes back as a sentence starting with "Not done".
    /// JavaScriptCore cannot be interrupted from outside, so a script that never ends keeps its own thread busy until the app closes;
    /// the caller gets the timeout answer and no further script runs until that thread ends.
    public static func run(script: String, input: String = "", timeout: TimeInterval = 3) async -> String {
        let code = script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return "Not done: no script was given." }
        guard code.count <= maxScript else { return "Not done: the script is longer than \(maxScript) characters." }
        guard input.count <= maxInput else { return "Not done: the input is longer than \(maxInput) characters." }
        if isStuck() { return "Not done: an earlier script is still running, so no new script can start until it ends or the app restarts." }
        return await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            let once = Once(cont)
            let thread = Thread {
                let out = evaluate(code, input: input)
                if !once.finish(out) { setStuck(false) }
            }
            thread.qualityOfService = .utility
            thread.stackSize = 8 << 20
            thread.start()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if once.finish("Not done: the script ran longer than \(Int(timeout)) seconds and was stopped.") { setStuck(true) }
            }
        }
    }

    static func evaluate(_ code: String, input: String) -> String {
        guard let context = JSContext() else { return "Not done: the script engine is not available." }
        let box = LogBox()
        context.exceptionHandler = { _, exception in box.error = exception?.toString() ?? "unknown error" }
        let log: @convention(block) (JSValue) -> Void = { value in box.lines.append(value.toString() ?? "") }
        let console = JSValue(newObjectIn: context)
        console?.setObject(log, forKeyedSubscript: "log" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)
        context.setObject(input, forKeyedSubscript: "input" as NSString)
        let result = context.evaluateScript(code)
        if let e = box.error { return "Not done: the script failed: \(String(e.prefix(300)))" }
        var parts = box.lines
        if let result, !result.isUndefined, !result.isNull, let text = result.toString() { parts.append(text) }
        var out = parts.joined(separator: "\n")
        if out.isEmpty { return "The script ran and printed nothing. Use console.log or end with the value to show." }
        var note = ""
        if out.count > maxOutput { out = String(out.prefix(maxOutput)); note = "\n(Cut after \(maxOutput) characters.)" }
        return "Script result:\n" + out + note
    }
}
