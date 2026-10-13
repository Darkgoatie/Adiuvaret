import Foundation
import Vision
import PDFKit
import UIKit
import ImageIO
import ToolKit
import Diagnostics

/// Reads the words out of a PDF or an image on this phone. A PDF's own text layer is used when it has one; scanned pages and
/// pictures go through Apple's text recognition (Vision). Nothing leaves the phone in this step.
enum DocumentText {
    struct Result: Sendable {
        let text: String
        let note: String
    }

    static let maxPDFPages = 30
    static let maxRecognizedPages = 10

    static func read(data: Data, kind: ContentKind) async -> Result? {
        await Task.detached(priority: .userInitiated) { () -> Result? in
            switch kind {
            case .pdf: return readPDF(data)
            case .image: return readImage(data)
            default: return nil
            }
        }.value
    }

    private static func readImage(_ data: Data) -> Result? {
        guard let image = cgImage(from: data) else { return nil }
        let text = recognize(image)
        DiagnosticsLog.shared.record("document", "image recognised, \(text.count) characters")
        return Result(text: text, note: "")
    }

    private static func readPDF(_ data: Data) -> Result? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return nil }
        let total = doc.pageCount
        var blocks: [String] = []
        var recognized = 0, used = 0, lastPage = 0
        for i in 0..<min(total, maxPDFPages) {
            guard let page = doc.page(at: i) else { continue }
            var text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count < 25, recognized < maxRecognizedPages, let image = render(page) {
                text = recognize(image)
                recognized += 1
            }
            lastPage = i + 1
            if !text.isEmpty { blocks.append("[page \(i + 1)]\n" + text); used += text.count }
            if used >= DocumentRead.maxChars { break }
        }
        let note = lastPage < total ? "pages 1 to \(lastPage) of \(total)" : ""
        DiagnosticsLog.shared.record("document", "pdf \(lastPage) of \(total) pages, \(recognized) recognised, \(used) characters")
        return Result(text: blocks.joined(separator: "\n\n"), note: note)
    }

    /// A downscaled copy, so a large photo does not use much memory.
    private static func cgImage(from data: Data, maxPixel: Int = 3200) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = min(3.0, 2400 / max(bounds.width, bounds.height))
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.cgImage
    }

    /// Lines in reading order: top to bottom, left to right inside a line.
    private static func recognize(_ image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil, let found = request.results else { return "" }
        let ordered = found.sorted { a, b in
            let ra = Int((1 - a.boundingBox.midY) * 150), rb = Int((1 - b.boundingBox.midY) * 150)
            return ra != rb ? ra < rb : a.boundingBox.minX < b.boundingBox.minX
        }
        return ordered.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

/// Downloads a PDF or an image for reading. Same address rules as the web tools; no cookies, no cache.
enum DocumentFetch {
    struct File: Sendable {
        let data: Data
        let kind: ContentKind
    }

    /// `cookieHeader` is only for the browser path, where the user may have signed in; with it, redirects are not followed so the cookies stay on their host.
    static func get(_ url: URL, cookieHeader: String? = nil, maxBytes: Int = 15_000_000, timeout: TimeInterval = 20) async -> File? {
        guard case .allowed(let start) = WebPolicy.normalize(url.absoluteString) else { return nil }
        var request = URLRequest(url: start, timeoutInterval: timeout)
        request.setValue(WebSearch.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/pdf,image/*;q=0.9,*/*;q=0.1", forHTTPHeaderField: "Accept")
        if let cookieHeader, !cookieHeader.isEmpty { request.setValue(cookieHeader, forHTTPHeaderField: "Cookie") }
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 10
        let session = URLSession(configuration: config, delegate: (cookieHeader ?? "").isEmpty ? nil : NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count <= maxBytes, let final = http.url, case .allowed = WebPolicy.normalize(final.absoluteString) else { return nil }
        let kind = ContentKind.classify(mime: http.mimeType, url: final)
        return kind.isDocument ? File(data: data, kind: kind) : nil
    }
}
