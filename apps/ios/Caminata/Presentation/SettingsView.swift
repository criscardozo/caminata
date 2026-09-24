import SwiftUI

struct SettingsView: View {
    let model: TrackingViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Leyenda sobre la imagen",
                        isOn: Bindable(model.settings).captionOnImage
                    )
                } header: {
                    Text("Imagen")
                } footer: {
                    Text("Escribe la fecha, la distancia, el tiempo y el ritmo sobre la imagen del mapa. Queda grabada en la foto, así que viene desactivada.")
                }

                Section {
                    ColorPicker(
                        "Color del recorrido",
                        selection: routeColor,
                        supportsOpacity: false
                    )
                    presetRow
                } header: {
                    Text("Recorrido")
                } footer: {
                    Text("Se usa en el mapa en vivo, en la imagen que se exporta y en la web. Cada caminata guarda el color con el que se dibujó.")
                }

                if model.cloudAvailable {
                    accountSection
                    if model.pendingUploads > 0 {
                        pendingSection
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var routeColor: Binding<Color> {
        Binding(
            get: { RouteColor.color(from: model.settings.routeColorHex) },
            set: { model.settings.routeColorHex = RouteColor.hex(from: $0) }
        )
    }

    /// The picker is fine but slow for a choice most people make once, so the
    /// colours that read well over map tiles are one tap away.
    private var presetRow: some View {
        HStack(spacing: 14) {
            ForEach(RouteColor.presets, id: \.self) { hex in
                Button {
                    model.settings.routeColorHex = hex
                } label: {
                    Circle()
                        .fill(RouteColor.color(from: hex))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    .primary,
                                    lineWidth: model.settings.routeColorHex.caseInsensitiveCompare(hex) == .orderedSame ? 3 : 0
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let name = model.accountName {
                LabeledContent("Sesión iniciada como", value: name)
                Button("Cerrar sesión", role: .destructive) { model.signOut() }
            } else {
                Button {
                    Task {
                        isSigningIn = true
                        await model.signIn()
                        isSigningIn = false
                    }
                } label: {
                    HStack {
                        Text("Iniciar sesión con Google")
                        Spacer()
                        if isSigningIn { ProgressView() }
                    }
                }
                .disabled(isSigningIn)
            }
        } header: {
            Text("Cuenta")
        } footer: {
            Text("Al iniciar sesión se suben el resumen y el recorrido de cada caminata terminada, para poder repasarlas en la web. El track GPS completo no sale del teléfono.")
        }
    }

    private var pendingSection: some View {
        Section {
            LabeledContent("Pendientes de subir", value: "\(model.pendingUploads)")
        } footer: {
            Text(model.accountName == nil
                 ? "Se van a subir cuando inicies sesión."
                 : "Se suben solas la próxima vez que abras la app con conexión.")
        }
    }
}
