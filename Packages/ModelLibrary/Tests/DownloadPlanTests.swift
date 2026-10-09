import Testing
import Foundation
@testable import ModelLibrary

@Suite struct DownloadPlanTests {
    /// Shape of the real answer from huggingface.co/api/models/mlx-community/gemma-3-1b-it-4bit/tree/main.
    static let tree = """
    [{"type":"file","oid":"a","size":1570,"path":".gitattributes"},
     {"type":"file","oid":"b","size":1168,"path":"README.md"},
     {"type":"file","oid":"c","size":35,"path":"added_tokens.json"},
     {"type":"file","oid":"d","size":1098,"path":"config.json"},
     {"type":"file","oid":"e","size":134,"path":"model.safetensors","lfs":{"oid":"x","size":732577304,"pointerSize":134}},
     {"type":"file","oid":"f","size":50542,"path":"model.safetensors.index.json"},
     {"type":"file","oid":"g","size":4689074,"path":"tokenizer.model","lfs":{"oid":"y","size":4689074,"pointerSize":134}},
     {"type":"file","oid":"h","size":33384568,"path":"tokenizer.json","lfs":{"oid":"z","size":33384568,"pointerSize":134}},
     {"type":"directory","oid":"i","size":0,"path":"onnx"},
     {"type":"file","oid":"j","size":9,"path":"onnx/model.safetensors"},
     {"type":"file","oid":"k","size":500,"path":"chat_template.jinja"}]
    """

    @Test func treeKeepsOnlyWeightsConfigAndTokenizerFiles() throws {
        let files = try DownloadPlan.files(fromTreeJSON: Data(Self.tree.utf8))
        #expect(files.map(\.path) == ["added_tokens.json", "chat_template.jinja", "config.json", "model.safetensors", "model.safetensors.index.json", "tokenizer.json"])
    }

    @Test func lfsSizeWinsOverThePointerSize() throws {
        let files = try DownloadPlan.files(fromTreeJSON: Data(Self.tree.utf8))
        #expect(files.first { $0.path == "model.safetensors" }?.size == 732_577_304)
        #expect(files.first { $0.path == "config.json" }?.size == 1098)
    }

    @Test func unsafePathsAreRefused() {
        for p in ["../x.json", "a/b.json", "/etc/x.json", ".hidden.json", "", "..", "a\\b.json"] {
            #expect(!DownloadPlan.isSafe(p), "\(p)")
            #expect(!DownloadPlan.wanted(p))
        }
        #expect(DownloadPlan.wanted("model-00001-of-00002.safetensors"))
        #expect(!DownloadPlan.wanted("README.md") && !DownloadPlan.wanted("tokenizer.model"))
    }

    @Test func badTreeJSONThrows() {
        #expect(throws: (any Error).self) { try DownloadPlan.files(fromTreeJSON: Data("{\"error\":\"nope\"}".utf8)) }
    }

    @Test func urlsAreBuiltOnlyForValidRepositories() {
        #expect(DownloadPlan.treeURL("mlx-community/Qwen3-1.7B-4bit")?.absoluteString == "https://huggingface.co/api/models/mlx-community/Qwen3-1.7B-4bit/tree/main")
        #expect(DownloadPlan.fileURL("mlx-community/Qwen3-1.7B-4bit", path: "model.safetensors")?.absoluteString == "https://huggingface.co/mlx-community/Qwen3-1.7B-4bit/resolve/main/model.safetensors")
        #expect(DownloadPlan.treeURL("../etc/passwd") == nil)
        #expect(DownloadPlan.treeURL("a/b/c") == nil)
        #expect(DownloadPlan.fileURL("mlx-community/x", path: "../a.json") == nil)
        #expect(DownloadPlan.fileURL("mlx-community/x", path: "a b.json")?.absoluteString.hasSuffix("a%20b.json") == true)
    }

    @Test func everyCatalogModelHasAValidRepositoryAndUniqueTaskIdentifier() {
        let ids = ModelCatalog.all.map { DownloadPlan.taskIdentifier(for: $0.id) }
        #expect(Set(ids).count == ModelCatalog.all.count)
        for m in ModelCatalog.all {
            #expect(DownloadPlan.isValidRepository(m.id), "\(m.id)")
            #expect(DownloadPlan.taskIdentifier(for: m.id).hasPrefix("com.halit.adiuvaret.download."))
        }
        #expect(DownloadPlan.taskIdentifier(for: "mlx-community/Qwen3-4B-Instruct-2507-4bit") == "com.halit.adiuvaret.download.qwen3-4b-instruct-2507-4bit")
        #expect(DownloadPlan.folderName(for: "mlx-community/gemma-3-1b-it-4bit") == "mlx-community--gemma-3-1b-it-4bit")
    }

    /// The system only starts a background task whose identifier is in Info.plist, so the file must list every model.
    @Test func infoPlistListsEveryTaskIdentifier() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        let plist = url.appendingPathComponent("Config/Info.plist")
        let data = try Data(contentsOf: plist)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let listed = Set(object?["BGTaskSchedulerPermittedIdentifiers"] as? [String] ?? [])
        for m in ModelCatalog.all { #expect(listed.contains(DownloadPlan.taskIdentifier(for: m.id)), "\(m.id) missing in Info.plist") }
    }
}

@Suite struct DownloadManifestTests {
    private let files = [RemoteFile(path: "config.json", size: 100), RemoteFile(path: "model.safetensors", size: 900)]

    @Test func progressCountsFinishedFilesAndBytesInFlight() {
        var m = DownloadManifest(id: "a/b", files: files)
        #expect(m.totalBytes == 1000 && m.fraction() == 0 && !m.isComplete)
        #expect(m.fraction(inFlight: ["model.safetensors": 450]) == 0.45)
        m.markDone("config.json")
        #expect(m.doneBytes == 100 && m.remaining.map(\.path) == ["model.safetensors"])
        #expect(m.fraction(inFlight: ["model.safetensors": 450]) == 0.55)
        #expect(m.fraction(inFlight: ["model.safetensors": 99_999, "config.json": 5]) == 1.0)
        m.markDone("model.safetensors")
        #expect(m.isComplete && m.fraction() == 1)
    }

    @Test func unknownFilesAndEmptyListsAreHandled() {
        var m = DownloadManifest(id: "a/b", files: files)
        m.markDone("other.json")
        #expect(m.done.isEmpty)
        #expect(!DownloadManifest(id: "a/b", files: []).isComplete)
        #expect(DownloadManifest(id: "a/b", files: []).fraction() == 0)
    }

    @Test func updatedListingKeepsFinishedFilesThatDidNotChange() {
        var m = DownloadManifest(id: "a/b", files: files)
        m.markDone("config.json"); m.markDone("model.safetensors")
        let changed = [RemoteFile(path: "config.json", size: 100), RemoteFile(path: "model.safetensors", size: 950), RemoteFile(path: "tokenizer.json", size: 5)]
        let next = m.updated(with: changed)
        #expect(next.done == ["config.json"] && next.files == changed)
    }

    @Test func manifestSurvivesSavingAndLoading() throws {
        var m = DownloadManifest(id: "a/b", files: files)
        m.markDone("config.json")
        let back = try JSONDecoder().decode(DownloadManifest.self, from: JSONEncoder().encode(m))
        #expect(back == m)
    }

    @Test func summaryTextShowsPercentAndSizes() {
        let text = DownloadText.summary(fraction: 0.425, totalBytes: 1_000_000_000)
        #expect(text.hasPrefix("42% ·") && text.contains(" of "))
        #expect(DownloadText.summary(fraction: 5, totalBytes: 100).hasPrefix("100%"))
        #expect(DownloadText.summary(fraction: -1, totalBytes: 100).hasPrefix("0%"))
    }
}
