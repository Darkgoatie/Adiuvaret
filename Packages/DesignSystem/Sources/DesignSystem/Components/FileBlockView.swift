import SwiftUI

/// A file the model wrote. Shows its name, size and the first lines, and lets the user save or share it as a real file.
struct FileBlockView: View {
    let file: GeneratedFile
    @State private var url: URL?

    private var preview: String {
        file.text.split(separator: "\n", omittingEmptySubsequences: false).prefix(8).joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Image(systemName: FileOutput.symbol(for: file.name)).imageScale(.large).foregroundStyle(DS.Colors.accentText).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: file.name).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                    Text(verbatim: FileOutput.sizeText(file)).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                if let url {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(verbatim: L("Save or share \(file.name)")))
                    .accessibilityIdentifier("file.share")
                }
            }
            Text(verbatim: preview).font(.system(.footnote, design: .monospaced)).foregroundStyle(DS.Colors.textSecondary).lineLimit(8)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .task(id: file) { url = FileOutput.write(file) }
    }
}
