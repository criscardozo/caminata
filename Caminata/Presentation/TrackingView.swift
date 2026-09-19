import MapKit
import SwiftUI

struct TrackingView: View {
    @State private var model = TrackingViewModel()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 16) {
                    if model.permissionNeeded {
                        permissionBanner
                    }
                    statsPanel
                    recordButton
                }
                .padding()
            }
            .navigationTitle("Caminata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("History", systemImage: "list.bullet")
                    }
                }
            }
        }
        .onAppear { model.onAppear() }
        .sheet(isPresented: $showingHistory) {
            HistoryView(model: model.makeHistoryModel())
        }
        .sheet(item: $model.export) { export in
            WalkSummaryView(export: export, emailBody: model.emailBody(for: export.walk))
        }
        .overlay {
            if model.isExporting {
                ProgressView("Drawing your route")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Caminata", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()

            if model.coordinates.count > 1 {
                MapPolyline(coordinates: model.coordinates)
                    .stroke(
                        .red,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }

            if let start = model.coordinates.first {
                Annotation("Start", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var statsPanel: some View {
        HStack {
            stat("Distance", WalkFormatting.distance(model.stats.distance))
            Divider()
            stat("Time", WalkFormatting.duration(model.stats.elapsed))
            Divider()
            stat("Pace", WalkFormatting.pace(model.stats.averagePace))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recordButton: some View {
        Button {
            model.toggleRecording()
        } label: {
            Label(
                model.isRecording ? "Stop" : "Play",
                systemImage: model.isRecording ? "stop.fill" : "play.fill"
            )
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.isRecording ? .red : .green)
        .disabled(model.permissionNeeded)
    }

    private var permissionBanner: some View {
        VStack(spacing: 8) {
            Text("Caminata needs your location to record a walk.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.footnote.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { presented in if !presented { model.errorMessage = nil } }
        )
    }
}

#Preview {
    TrackingView()
}
