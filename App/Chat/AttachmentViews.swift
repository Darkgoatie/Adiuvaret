import SwiftUI
import DesignSystem
import ModelLibrary

/// One attached file: a thumbnail for pictures, an icon and the name for documents.
struct AttachmentChip: View {
    let attachment: ChatFile
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.s) {
            if let image = AttachmentStore.thumbnail(attachment) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.s)).accessibilityHidden(true)
            } else {
                Image(systemName: FileOutput.symbol(for: attachment.name)).imageScale(.large).foregroundStyle(DS.Colors.accentText)
                    .frame(width: 44, height: 44).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: attachment.name).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
                Text(verbatim: ByteCountFormatter.string(fromByteCount: Int64(attachment.bytes), countStyle: .file))
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: 160, alignment: .leading)
            if let onRemove {
                Button(action: onRemove) { Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Colors.textSecondary).frame(width: 44, height: 44) }
                    .accessibilityLabel(Text("Remove \(attachment.name)"))
            }
        }
        .padding(.leading, Spacing.xs).padding(.trailing, onRemove == nil ? Spacing.m : 0)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
        .accessibilityElement(children: onRemove == nil ? .combine : .contain)
    }
}

/// The files that went with one of the user's messages, shown above it.
struct AttachmentRow: View {
    let files: [ChatFile]

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            ForEach(files) { AttachmentChip(attachment: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Attached: \(files.map(\.name).joined(separator: ", "))"))
    }
}
