import Foundation
import Network
import os

/// One look at the current connection, taken when a download is about to start.
enum NetworkCheck {
    struct Snapshot: Sendable {
        let isExpensive: Bool
        let isConstrained: Bool
    }

    static func current() async -> Snapshot {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let answered = OSAllocatedUnfairLock(initialState: false)
            monitor.pathUpdateHandler = { path in
                let already = answered.withLock { done -> Bool in
                    let was = done
                    done = true
                    return was
                }
                guard !already else { return }
                monitor.cancel()
                continuation.resume(returning: Snapshot(isExpensive: path.isExpensive, isConstrained: path.isConstrained))
            }
            monitor.start(queue: DispatchQueue(label: "adiuvaret.network-check"))
        }
    }
}
