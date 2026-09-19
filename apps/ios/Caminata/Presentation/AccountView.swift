import SwiftUI

/// Signing in is the only thing that connects the phone to the web history,
/// so this screen says what it is for rather than just offering a button.
struct AccountView: View {
    let model: TrackingViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let name = model.accountName {
                        LabeledContent("Signed in as", value: name)
                    } else {
                        Text("Your walks stay on this phone until you sign in.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Signing in with Google uploads the summary and the route of each finished walk, so you can look back through them on the web. The full GPS track never leaves the phone.")
                }

                Section {
                    if model.accountName == nil {
                        Button {
                            Task {
                                isSigningIn = true
                                await model.signIn()
                                isSigningIn = false
                            }
                        } label: {
                            HStack {
                                Text("Sign in with Google")
                                Spacer()
                                if isSigningIn { ProgressView() }
                            }
                        }
                        .disabled(isSigningIn)
                    } else {
                        Button("Sign out", role: .destructive) { model.signOut() }
                    }
                }

                if model.pendingUploads > 0 {
                    Section {
                        LabeledContent("Waiting to upload", value: "\(model.pendingUploads)")
                    } footer: {
                        Text(model.accountName == nil
                             ? "These will go up once you sign in."
                             : "These go up on their own next time the app opens with a connection.")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
