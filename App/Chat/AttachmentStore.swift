import Foundation
import UIKit
import PDFKit
import ModelLibrary

enum AttachmentError: Error {
    case unsupported, tooLarge, unreadable

    var message: String {
        switch self {
        case .unsupported: String(localized: "That file type can't be attached. Use a text, document, code or image file.")
        case .tooLarge: String(localized: "That file is larger than 10 MB.")
        case .unreadable: String(localized: "That file could not be read.")
        }
    }
}

/// What a model receives for one turn: the text of documents, and images in the form the model takes.
struct PreparedFiles {
    var documents: [AttachmentText.Doc] = []
    /// Images a local vision model reads from disk.
    var imageURLs: [URL] = []
    /// Images an online model receives, resized and encoded.
    var wireImages: [ProviderWire.Image] = []
    /// Images the chosen model cannot view, so the reply can say so.
    var skippedImageNames: [String] = []
}

/// Copies of attached files, kept in Application Support so a chat can still show them after a relaunch. Nothing here leaves the phone except what a send includes.
enum AttachmentStore {
    static let maxImageSide: CGFloat = 1568
    static let maxTextChars = 400_000

    static var folder: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(_ a: Attachment) -> URL { folder.appendingPathComponent(a.stored) }

    /// Copies a file chosen in the file picker. Images are resized and stored as JPEG.
    static func importFile(_ source: URL) throws -> Attachment {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let name = source.lastPathComponent
        guard let kind = AttachmentRules.kind(forFileName: name) else { throw AttachmentError.unsupported }
        guard let data = try? Data(contentsOf: source, options: .mappedIfSafe) else { throw AttachmentError.unreadable }
        guard data.count <= AttachmentRules.maxFileBytes else { throw AttachmentError.tooLarge }
        switch kind {
        case .image:
            guard let a = importPhoto(data: data, name: name) else { throw AttachmentError.unreadable }
            return a
        case .document:
            let stored = "\(UUID().uuidString).\((name as NSString).pathExtension.lowercased())"
            do { try data.write(to: folder.appendingPathComponent(stored), options: .atomic) } catch { throw AttachmentError.unreadable }
            return Attachment(name: name, kind: .document, stored: stored, bytes: data.count)
        }
    }

    /// A picked photo or image file, resized so a send stays small.
    static func importPhoto(data: Data, name: String = "") -> Attachment? {
        guard let image = UIImage(data: data), let jpeg = resized(image).jpegData(compressionQuality: 0.8) else { return nil }
        let stored = "\(UUID().uuidString).jpg"
        guard (try? jpeg.write(to: folder.appendingPathComponent(stored), options: .atomic)) != nil else { return nil }
        let label = name.isEmpty ? String(localized: "Photo") + ".jpg" : (((name as NSString).deletingPathExtension) + ".jpg")
        return Attachment(name: label, kind: .image, stored: stored, bytes: jpeg.count)
    }

    private static func resized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxImageSide else { return image }
        let scale = maxImageSide / longest
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func thumbnail(_ a: Attachment) -> UIImage? { a.kind == .image ? UIImage(contentsOfFile: url(a).path) : nil }

    /// The text of a document. PDF and RTF are read by the system; everything else is read as text.
    static func text(of a: Attachment) -> String {
        let file = url(a)
        switch (a.name as NSString).pathExtension.lowercased() {
        case "pdf": return String((PDFDocument(url: file)?.string ?? "").prefix(maxTextChars))
        case "rtf":
            let attributed = try? NSAttributedString(url: file, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return String((attributed?.string ?? "").prefix(maxTextChars))
        default:
            guard let data = try? Data(contentsOf: file) else { return "" }
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            return String(text.prefix(maxTextChars))
        }
    }

    static func prepare(_ files: [Attachment], support: AttachmentSupport) -> PreparedFiles {
        var out = PreparedFiles()
        for a in files {
            switch a.kind {
            case .document:
                out.documents.append(.init(name: a.name, text: text(of: a)))
            case .image:
                guard support.images else { out.skippedImageNames.append(a.name); continue }
                out.imageURLs.append(url(a))
                if let data = try? Data(contentsOf: url(a)) { out.wireImages.append(.init(mediaType: "image/jpeg", base64: data.base64EncodedString())) }
            }
        }
        return out
    }

    static func remove(_ files: [Attachment]) {
        for a in files { try? FileManager.default.removeItem(at: url(a)) }
    }
}
