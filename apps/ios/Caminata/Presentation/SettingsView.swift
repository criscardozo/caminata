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
