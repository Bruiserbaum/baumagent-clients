import SwiftUI

@main
struct BaumAgentApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task { await UpdateService.shared.checkForUpdate() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 680)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false

    init() {
        isAuthenticated = KeychainService.shared.hasCredentials()
    }

    func signedIn() { isAuthenticated = true }
    func signedOut() {
        KeychainService.shared.clear()
        isAuthenticated = false
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.isAuthenticated {
            ShellView()
        } else {
            PairingView()
        }
    }
}
