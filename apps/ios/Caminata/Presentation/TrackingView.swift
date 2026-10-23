import MapKit
import SwiftUI
import UIKit

struct TrackingView: View {
    @State private var model = TrackingViewModel()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showingHistory = false
    @State private var showingSettings = false
    @Namespace private var mapScope

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 16) {
                    if model.permissionNeeded {
                        permissionBanner
                    }
                    mapButtons
                    statsPanel
                    recordButton
                }
                .padding()
            }
            // The controls live outside the Map, so they need its scope to know
            // which map they drive.
            .mapScope(mapScope)
            .navigationTitle("Caminata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("Historial", systemImage: "list.bullet")
                    }
                }
            }
        }
        .onAppear { model.onAppear() }
        .sheet(isPresented: $showingHistory) {
            HistoryView(model: model.makeHistoryModel())
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: model)
        }
        .sheet(item: $model.export) { export in
            WalkSummaryView(export: export, emailBody: model.emailBody(for: export))
        }
        .overlay {
            if model.isExporting {
                ProgressView("Dibujando tu recorrido")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Caminata", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var map: some View {
        Map(position: $camera, scope: mapScope) {
            UserAnnotation()

            if model.coordinates.count > 1 {
                MapPolyline(coordinates: model.coordinates)
                    .stroke(
                        RouteColor.color(from: model.settings.routeColorHex),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }

            if let start = model.coordinates.first {
                Annotation("Inicio", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .frame(width: 16, height: 16)
                }
            }
        }
        // No built-in controls: the map runs up under the navigation bar, so
        // MapKit's top-trailing corner is the screen's, and its buttons landed
        // under the status bar and on top of the history button.
        .mapControls {}
    }

    /// Bottom-trailing, just above the figures: clear of the toolbar, and where
    /// a thumb already is.
    private var mapButtons: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                MapCompass(scope: mapScope)
                MapUserLocationButton(scope: mapScope)
            }
            .buttonBorderShape(.circle)
        }
    }

    private var statsPanel: some View {
        HStack {
            stat("Distancia", WalkFormatting.distance(model.stats.distance))
            divider
            stat("Tiempo", WalkFormatting.duration(model.stats.elapsed))
            divider
            stat("Ritmo", WalkFormatting.pace(model.stats.averagePace))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        // Without this the panel takes every point the ZStack will give it,
        // which is the whole screen.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A bare Divider stretches to whatever height it is offered, and in an
    /// HStack that is however tall the stack is allowed to be.
    private var divider: some View {
        Divider().frame(height: 34)
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
                model.isRecording ? "Detener" : "Empezar",
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
            Text("Caminata necesita tu ubicación para registrar el recorrido.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Abrir Ajustes") {
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
