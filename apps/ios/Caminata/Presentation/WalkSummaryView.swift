import Photos
import SwiftUI
import UIKit

struct WalkSummaryView: View {
    let export: WalkExport
    let emailBody: String

    @Environment(\.dismiss) private var dismiss
    @State private var showingMail = false
    @State private var savedToPhotos = false
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: export.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    statsGrid

                    VStack(spacing: 12) {
                        if MailComposeView.canSendMail {
                            Button {
                                showingMail = true
                            } label: {
                                Label("Enviar por mail", systemImage: "envelope.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        ShareLink(items: export.attachments) {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)

                        if let webURL = export.webURL {
                            Link(destination: webURL) {
                                Label("Verla en la web", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            Task { await saveToPhotos() }
                        } label: {
                            Label(
                                savedToPhotos ? "Guardada en Fotos" : "Guardar en Fotos",
                                systemImage: savedToPhotos ? "checkmark" : "photo"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(savedToPhotos)
                    }
                }
                .padding()
            }
            .navigationTitle(export.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
            .alert("Caminata", isPresented: saveErrorBinding) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: $showingMail) {
                MailComposeView(
                    subject: export.name,
                    body: emailBody,
                    attachments: export.attachments.compactMap(MailComposeView.Attachment.from(url:)),
                    onFinish: { showingMail = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    /// Goes through PhotosKit rather than `UIImageWriteToSavedPhotosAlbum` so
    /// that a refused permission is reported instead of leaving the button
    /// claiming the image was saved when it never was.
    private func saveToPhotos() async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: export.image)
            }
            savedToPhotos = true
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { presented in if !presented { saveErrorMessage = nil } }
        )
    }

    private var statsGrid: some View {
        let stats = export.walk.stats
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            summaryTile("Distancia", WalkFormatting.distance(stats.distance))
            summaryTile("Duración", WalkFormatting.duration(stats.elapsed))
            summaryTile("En movimiento", WalkFormatting.duration(stats.movingTime))
            summaryTile("Ritmo", WalkFormatting.pace(stats.averagePace))
        }
    }

    private func summaryTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
