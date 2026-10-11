import Foundation

/// Which long-press actions a message may offer. Pure logic over a list of roles so it can be tested without the app.
public enum ThreadEditing {
    public enum Role: Sendable, Equatable { case user, assistant, other }

    /// Your own messages can be edited, and only while no reply is being written.
    public static func canEdit(_ roles: [Role], at i: Int, generating: Bool) -> Bool {
        !generating && roles.indices.contains(i) && roles[i] == .user
    }

    /// Only the newest assistant reply can be asked again, and only when you have not written anything after it.
    public static func canRegenerate(_ roles: [Role], at i: Int, generating: Bool) -> Bool {
        guard !generating, roles.indices.contains(i), roles[i] == .assistant else { return false }
        guard !roles[(i + 1)...].contains(where: { $0 == .user || $0 == .assistant }) else { return false }
        return roles[..<i].contains(.user)
    }

    /// Any message of yours or the assistant's. Tool rows and cards are not deleted one by one.
    public static func canDelete(_ roles: [Role], at i: Int, generating: Bool) -> Bool {
        !generating && roles.indices.contains(i) && roles[i] != .other
    }

    /// The user message a reply answers, and how many items stay when the reply is replaced.
    public static func regenerationPoint(_ roles: [Role], at i: Int) -> (keep: Int, prompt: Int)? {
        guard roles.indices.contains(i), roles[i] == .assistant, let p = roles[..<i].lastIndex(of: .user) else { return nil }
        return (p + 1, p)
    }
}
