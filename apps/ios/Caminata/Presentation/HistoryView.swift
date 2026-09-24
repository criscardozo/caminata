import SwiftUI

struct HistoryView: View {
    @State var model: HistoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.walks.isEmpty {
                    ContentUnavailableView(
                        "Todavía no hay caminatas",
                        systemImage: "figure.walk",
                        description: Text("Las caminatas que termines aparecen acá.")
                    )
                } else {
                    List {
                        ForEach(model.walks) { walk in
                            Button {
                                Task { await model.open(walk) }
                            } label: {
                                row(for: walk)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            Task { await model.delete(at: offsets) }
                        }
                    }
                }
            }
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
            .overlay {
                if model.isExporting {
                    ProgressView("Dibujando tu recorrido")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onAppear { model.load() }
        .sheet(item: $model.export) { export in
            WalkSummaryView(export: export, emailBody: model.emailBody(for: export))
        }
        .alert("Caminata", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func row(for walk: WalkMetadata) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WalkFormatting.walkName(startedAt: walk.startedAt))
                .font(.headline)
            Text(subtitle(for: walk))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func subtitle(for walk: WalkMetadata) -> String {
        var parts: [String] = []
        if let distance = walk.distance {
            parts.append(WalkFormatting.distance(distance))
        }
        if let duration = walk.duration {
            parts.append(WalkFormatting.duration(duration))
        }
        return parts.isEmpty ? "Tocá para abrir" : parts.joined(separator: "  ·  ")
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { presented in if !presented { model.errorMessage = nil } }
        )
    }
}
