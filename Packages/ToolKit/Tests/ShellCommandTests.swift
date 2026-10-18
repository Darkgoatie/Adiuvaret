import Testing
import Foundation
@testable import ToolKit

@Suite struct ShellCommandTests {
    static let ws = "/var/app/Documents/Shell"

    static let rebuilt: [(String, String)] = [
        (#"ls -la"#, #"ls -la"#),
        (#"grep 'two words' a.txt | wc -l"#, #"grep 'two words' a.txt | wc -l"#),
        (#"echo "hello world" > out.txt"#, #"echo 'hello world' > out.txt"#),
        (#"sed 's/a b/c d/' a.txt"#, #"sed 's/a b/c d/' a.txt"#),
        (#"ls&&rm a"#, #"ls && rm a"#),
        (#"echo   a    b"#, #"echo a b"#),
        (#"grep -e '$HOME' f"#, #"grep -e '$HOME' f"#),
        (#"echo '~' > f"#, #"echo '~' > f"#),
        (#"cat a.txt 2>&1 | sort -u"#, #"cat a.txt 2>&1 | sort -u"#),
        (#"echo ''"#, #"echo ''"#),
        (#"echo a\ b"#, #"echo 'a b'"#),
        (#"cat ~/a.txt"#, #"cat '~/a.txt'"#),
        (#"echo x=y"#, #"echo 'x=y'"#),
        (#"sort < a.txt > b.txt"#, #"sort < a.txt > b.txt"#),
    ]

    @Test func aCheckedLineIsRebuiltInOneCleanForm() {
        for (line, expected) in Self.rebuilt {
            #expect(ShellCommandBuilder.rebuild(line) == expected, Comment(rawValue: line))
        }
    }

    @Test func aLineThatCannotBeParsedGivesNothing() {
        for line in ["", "   ", "echo 'open", "echo $HOME", "ls &"] {
            #expect(ShellCommandBuilder.rebuild(line) == nil, Comment(rawValue: line))
        }
    }

    @Test func rebuildingKeepsEveryWordAndOperator() {
        for (line, _) in Self.rebuilt {
            let before = ShellPolicy.tokenize(line).tokens
            let after = ShellPolicy.tokenize(ShellCommandBuilder.rebuild(line) ?? "").tokens
            #expect(before == after, Comment(rawValue: line))
        }
    }

    @Test func wordsIos_systemCouldExpandAreAlwaysQuoted() {
        for word in ["~", "~/x", "$HOME", "*", "?", "[a]", "a*b", ".*", "x=y", "=x", "a;b", "a|b", "a&b", "a>b", "#c", "a^b", "-", ""] {
            let q = ShellCommandBuilder.quote(word)
            #expect(q.hasPrefix("'") && q.hasSuffix("'"), Comment(rawValue: word))
        }
        #expect(ShellCommandBuilder.quote("a.txt") == "a.txt" && ShellCommandBuilder.quote("-rf") == "-rf" && ShellCommandBuilder.quote("notes/a-b_c.md") == "notes/a-b_c.md")
        #expect(ShellCommandBuilder.quote("it's") == ##"'it'\''s'"##)
    }

    @Test func theAnswerSaysWhatHappened() {
        #expect(ShellCommandBuilder.answer(output: "a\nb\n", status: 0, timedOut: false) == "a\nb")
        #expect(ShellCommandBuilder.answer(output: "", status: 0, timedOut: false) == "Done. The command printed nothing.")
        #expect(ShellCommandBuilder.answer(output: "boom", status: 2, timedOut: false) == "boom\n[exit status 2]")
        #expect(ShellCommandBuilder.answer(output: "", status: 1, timedOut: false) == "[exit status 1]")
        #expect(ShellCommandBuilder.answer(output: "partial", status: 0, timedOut: true) == "partial\n[stopped after 20 seconds]")
        #expect(ShellCommandBuilder.answer(output: "", status: 0, timedOut: true) == "[stopped after 20 seconds]")
        let long = String(repeating: "x", count: 5000)
        let cut = ShellCommandBuilder.answer(output: long, status: 0, timedOut: false, limit: 1000)
        #expect(cut.utf8.count < 1100 && cut.contains("[output cut"))
    }

    @Test func theCardShowsTheCommandWhatItDoesAndWhereItConnects() {
        let plan = ShellPolicy.plan("curl -o page.html https://Example.com/x && ls", workspace: Self.ws)
        let rows = ShellCommandBuilder.cardRows(command: "curl -o page.html https://Example.com/x && ls", plan: plan)
        #expect(rows.first?.label == "Command" && rows.first?.value.hasPrefix("curl") == true)
        #expect(rows.contains { $0.label == "Connects to" && $0.value == "example.com" })
        #expect(rows.contains { $0.label == "Steps" && $0.value == "curl, then ls" })
        let plain = ShellCommandBuilder.cardRows(command: "touch a", plan: ShellPolicy.plan("touch a", workspace: Self.ws))
        #expect(plain.count == 2 && !plain.contains { $0.label == "Connects to" })
        #expect(ShellCommandBuilder.cardTitle(for: .delete).contains("deletes") && ShellCommandBuilder.cardTitle(for: .network).contains("internet"))
        let longCommand = "echo " + String(repeating: "a", count: 900)
        #expect(ShellCommandBuilder.cardRows(command: longCommand, plan: ShellPolicy.plan(longCommand, workspace: Self.ws))[0].value.count == 400)
    }

    @Test func absolutePathsBecomeWorkspaceRelative() {
        let ws = Self.ws
        #expect(ShellCommandBuilder.relativePaths([ws + "/a.txt", ws + "/notes/b.md", "/etc/x", ws + "x"], workspace: ws) == ["a.txt", "notes/b.md"])
        #expect(ShellCommandBuilder.relativePaths([ws + "/.env"], workspace: ws + "/") == [".env"])
    }
}
