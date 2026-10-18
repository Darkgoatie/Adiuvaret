import Foundation
import ToolKit
import ios_system

/// Runs checked command lines inside the Shell folder. One command at a time, 20 seconds at most, 64 KB of output at most.
/// ios_system keeps process-wide state (current folder, environment), so every call waits its turn here.
actor ShellRunner {
    static let shared = ShellRunner()

    private var ready = false

    /// The folder the shell works in. Created on first use.
    nonisolated static var workspace: URL {
        let docs = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("Shell", isDirectory: true)
    }

    nonisolated static var workspacePath: String { workspace.path }

    struct Result: Sendable {
        let output: String
        let status: Int32
        let timedOut: Bool
    }

    /// Runs a line the caller already checked with `ShellPolicy`. The caller passes the rebuilt text from `ShellCommandBuilder`.
    func run(_ command: String) async -> Result {
        prepare()
        let root = Self.workspacePath
        _ = ios_setMiniRoot(root)
        FileManager.default.changeCurrentDirectoryPath(root)
        ios_setDirectoryURL(Self.workspace)

        let sink = OutputSink()
        guard sink.open() else { return Result(output: "Not done: the shell could not start.", status: 1, timedOut: false) }
        let thread = Thread { sink.runOnThread(command) }
        thread.stackSize = 4 << 20
        thread.start()

        let deadline = Date().addingTimeInterval(ShellPolicy.timeLimit)
        while !sink.finished, Date() < deadline { try? await Task.sleep(for: .milliseconds(40)) }
        var timedOut = false
        if !sink.finished {
            timedOut = true
            ios_kill()
            let grace = Date().addingTimeInterval(2)
            while !sink.finished, Date() < grace { try? await Task.sleep(for: .milliseconds(40)) }
        }
        let text = sink.collect()
        return Result(output: text, status: timedOut ? 124 : sink.status, timedOut: timedOut)
    }

    /// The paths in the workspace, relative to it, for the credential check on broad commands.
    nonisolated static func listing() -> [String] {
        let root = workspace
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: []) else { return [] }
        var out: [String] = []
        for case let url as URL in walker {
            out.append(url.path)
            if out.count > 5000 { break }
        }
        return ShellCommandBuilder.relativePaths(out, workspace: root.path)
    }

    private func prepare() {
        guard !ready else { return }
        ready = true
        try? FileManager.default.createDirectory(at: Self.workspace, withIntermediateDirectories: true)
        if let ca = Bundle.main.path(forResource: "cacert", ofType: "pem") { setenv("SSL_CERT_FILE", ca, 1); setenv("CURL_CA_BUNDLE", ca, 1) }
        setenv("HOME", Self.workspacePath, 1)
        setenv("TERM", "dumb", 1)
        sideLoading = false
        initializeEnvironment()
    }
}

/// Collects what a command prints into a temporary file, so a command that never ends cannot grow memory.
private final class OutputSink: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    private var code: Int32 = 0
    private let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("shell-\(UUID().uuidString).txt")
    private var out: UnsafeMutablePointer<FILE>?
    private var empty: UnsafeMutablePointer<FILE>?

    var finished: Bool { lock.lock(); defer { lock.unlock() }; return done }
    var status: Int32 { lock.lock(); defer { lock.unlock() }; return code }

    func open() -> Bool {
        out = fopen(url.path, "w")
        empty = fopen("/dev/null", "r")
        return out != nil && empty != nil
    }

    func runOnThread(_ command: String) {
        ios_switchSession(UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        ios_setContext(UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        ios_setStreams(empty, out, out)
        let result = ios_system(command)
        fflush(out)
        lock.lock(); code = result; done = true; lock.unlock()
    }

    func collect() -> String {
        defer { try? FileManager.default.removeItem(at: url) }
        if let out { fclose(out); self.out = nil }
        if let empty { fclose(empty); self.empty = nil }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: ShellPolicy.outputLimit + 4)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
