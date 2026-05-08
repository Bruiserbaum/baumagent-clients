import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updater = UpdateService.shared
    @State private var tokens: [ApiToken] = []
    @State private var tokensError: String?
    @State private var creds: Credentials?
    @State private var showRevokeConfirm = false
    @State private var showSignOutConfirm = false
    @State private var pendingRevokeId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.title2).bold()

                // Account
                GroupBox("Account") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("User").foregroundStyle(.secondary).font(.caption)
                            Text(creds?.displayName ?? "—").font(.callout)
                        }
                        GridRow {
                            Text("Email").foregroundStyle(.secondary).font(.caption)
                            Text(creds?.email ?? "—").font(.callout)
                        }
                        GridRow {
                            Text("Server").foregroundStyle(.secondary).font(.caption)
                            Text(creds?.url ?? "—").font(.callout).lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                // Tokens
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Tokens").fontWeight(.semibold)
                            Spacer()
                            Button("Refresh") { Task { await loadTokens() } }
                                .font(.caption)
                        }
                        if let err = tokensError {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                        ForEach(tokens) { token in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token.name.isEmpty ? "Token …\(token.id.suffix(8))" : token.name)
                                        .font(.callout)
                                    Text(token.lastUsedAt.map { "Last used \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Never used")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Revoke") {
                                    pendingRevokeId = token.id
                                    showRevokeConfirm = true
                                }
                                .foregroundStyle(.red)
                                .font(.caption)
                            }
                            Divider()
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Danger zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account").fontWeight(.semibold).foregroundStyle(.red)
                        HStack(spacing: 8) {
                            Button("Re-pair device") { rePair() }
                            Button("Sign out & unpair") { showSignOutConfirm = true }
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Updates
                GroupBox("Updates") {
                    VStack(alignment: .leading, spacing: 8) {
                        if updater.isChecking {
                            HStack { ProgressView(); Text("Checking…").font(.callout) }
                        } else if let update = updater.availableUpdate {
                            Text("v\(update.version) available").fontWeight(.semibold).foregroundStyle(.blue)
                            if !update.notes.isEmpty {
                                Text(update.notes).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            }
                            Button("Open Release Page") { updater.openReleasePage() }
                                .buttonStyle(.borderedProminent)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("Up to date").font(.callout)
                                Spacer()
                                Button("Check now") { Task { await updater.checkForUpdate() } }
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // About
                GroupBox("About") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BaumAgent macOS Client v1.0.0").font(.callout)
                        Text("SwiftUI · URLSession · Keychain · SFSpeechRecognizer")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(20)
        }
        .navigationTitle("Settings")
        .task {
            creds = KeychainService.shared.load()
            await loadTokens()
        }
        .confirmationDialog("Revoke token?", isPresented: $showRevokeConfirm, titleVisibility: .visible) {
            Button("Revoke", role: .destructive) {
                if let id = pendingRevokeId { Task { await revokeToken(id: id) } }
            }
        } message: { Text("This will permanently delete this API token.") }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await signOut() } }
        } message: { Text("Remove your credentials from this Mac. You'll need to re-pair to use the app.") }
    }

    private func loadTokens() async {
        do { tokens = try await APIService.shared.listTokens(); tokensError = nil }
        catch { tokensError = error.localizedDescription }
    }

    private func revokeToken(id: String) async {
        do { try await APIService.shared.revokeToken(id: id); await loadTokens() }
        catch { tokensError = "Revoke failed: \(error.localizedDescription)" }
    }

    private func rePair() {
        KeychainService.shared.clear()
        appState.signedOut()
    }

    private func signOut() async {
        do {
            let ts = try await APIService.shared.listTokens()
            for t in ts { try? await APIService.shared.revokeToken(id: t.id) }
        } catch {}
        KeychainService.shared.clear()
        appState.signedOut()
    }
}
