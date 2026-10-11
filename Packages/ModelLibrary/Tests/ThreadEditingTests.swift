import Testing
@testable import ModelLibrary

@Suite struct ThreadEditingTests {
    typealias R = ThreadEditing.Role
    private let thread: [R] = [.user, .other, .assistant, .user, .other, .other, .assistant, .other]

    @Test func onlyYourOwnMessagesCanBeEdited() {
        #expect(ThreadEditing.canEdit(thread, at: 0, generating: false))
        #expect(ThreadEditing.canEdit(thread, at: 3, generating: false))
        #expect(!ThreadEditing.canEdit(thread, at: 2, generating: false))
        #expect(!ThreadEditing.canEdit(thread, at: 1, generating: false))
        #expect(!ThreadEditing.canEdit(thread, at: 99, generating: false))
        #expect(!ThreadEditing.canEdit(thread, at: -1, generating: false))
    }

    @Test func nothingChangesWhileAReplyIsBeingWritten() {
        for i in thread.indices {
            #expect(!ThreadEditing.canEdit(thread, at: i, generating: true))
            #expect(!ThreadEditing.canRegenerate(thread, at: i, generating: true))
            #expect(!ThreadEditing.canDelete(thread, at: i, generating: true))
        }
    }

    @Test func onlyTheNewestReplyCanBeAskedAgain() {
        #expect(ThreadEditing.canRegenerate(thread, at: 6, generating: false))
        #expect(!ThreadEditing.canRegenerate(thread, at: 2, generating: false))
        #expect(!ThreadEditing.canRegenerate(thread, at: 3, generating: false))
        #expect(!ThreadEditing.canRegenerate([.assistant], at: 0, generating: false))
        #expect(!ThreadEditing.canRegenerate([.user, .assistant, .user], at: 1, generating: false))
    }

    @Test func deleteCoversMessagesButNotToolRows() {
        #expect(ThreadEditing.canDelete(thread, at: 0, generating: false))
        #expect(ThreadEditing.canDelete(thread, at: 6, generating: false))
        #expect(!ThreadEditing.canDelete(thread, at: 4, generating: false))
    }

    @Test func aReplyPointsBackToItsQuestion() {
        let point = ThreadEditing.regenerationPoint(thread, at: 6)
        #expect(point?.prompt == 3 && point?.keep == 4, Comment(rawValue: "\(String(describing: point))"))
        #expect(ThreadEditing.regenerationPoint(thread, at: 2)?.prompt == 0)
        #expect(ThreadEditing.regenerationPoint(thread, at: 3) == nil)
        #expect(ThreadEditing.regenerationPoint([.assistant], at: 0) == nil)
    }
}
