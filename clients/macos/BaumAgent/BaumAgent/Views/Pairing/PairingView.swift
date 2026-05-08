import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appState: AppState
    @State private var url = ""
    @State private var code = ""
    @State private var deviceName = ProcessInfo.processInfo.hostName
    @State private var urlVerified = false
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BaumAgent")
                .font(.largeTitle).bold()
                .padding(.bottom, 4)
            Text("Connect to your self-hosted server")
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            // Step 1: server URL
            GroupBox("Server URL") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://baum.example.com", text: $url)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Check connection") { Task { await checkUrl() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(loading || url.isEmpty)
                        if urlVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.bottom, 12)

            // Step 2: pairing code
            GroupBox("Pairing Code") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generate a code in the BaumAgent web portal under Settings → Pair Device.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Pairing code", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!urlVerified)
                    TextField("Device name", text: $deviceName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!urlVerified)
                    Button("Pair device") { Task { await pair() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(!urlVerified || code.isEmpty || loading)
                }
                .padding(.vertical, 4)
            }
            .opacity(urlVerified ? 1 : 0.4)

            if let err = error {
                Text(err).foregroundStyle(.red).font(.caption).padding(.top, 8)
            }
            if loading {
                ProgressView().padding(.top, 8)
            }
        }
        .padding(40)
        .frame(width: 440)
    }

    private func checkUrl() async {
        loading = true; error = nil
        do {
            _ = try await APIService.shared.checkHealth(url: url)
            urlVerified = true
        } catch {
            self.error = "Cannot reach server: \(error.localizedDescription)"
        }
        loading = false
    }

    private func pair() async {
        loading = true; error = nil
        do {
            let resp = try await APIService.shared.completePairing(
                url: url, code: code, deviceName: deviceName)
            KeychainService.shared.save(Credentials(
                url: url, token: resp.token,
                email: resp.userEmail, displayName: resp.userDisplayName))
            appState.signedIn()
        } catch {
            self.error = "Pairing failed: \(error.localizedDescription)"
        }
        loading = false
    }
}
