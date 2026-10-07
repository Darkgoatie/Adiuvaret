import SwiftUI

struct SpikeView: View {
    @State private var model = SpikeModel()

    var body: some View {
        Form {
            Section("Prompt") {
                TextField("Ask something", text: $model.prompt, axis: .vertical)
                Button("Send") { Task { await model.send() } }.disabled(model.running)
                Button("Measure context and tools") { Task { await model.contextReport() } }.disabled(model.running)
            }
            Section("Answer") { Text(model.output.isEmpty ? "-" : model.output) }
            Section("Report") {
                Text(model.report.isEmpty ? "-" : model.report).font(.caption.monospaced())
                if !model.report.isEmpty { ShareLink("Share report", item: model.report) }
            }
        }
        .navigationTitle("Spike")
        .alert(model.pending?.title ?? "", isPresented: Binding(get: { model.pending != nil }, set: { _ in })) {
            Button("Approve") { model.answer(.approved) }
            Button("Deny", role: .destructive) { model.answer(.denied) }
        } message: {
            Text(model.pending?.detail ?? "")
        }
    }
}
