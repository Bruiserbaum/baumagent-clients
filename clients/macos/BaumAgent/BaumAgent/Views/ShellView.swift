import SwiftUI

enum NavDest: Hashable {
    case tasks
    case create
    case settings
    case taskDetail(String)
}

struct ShellView: View {
    @State private var selection: NavDest = .tasks
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Tasks", systemImage: "list.bullet").tag(NavDest.tasks)
                Label("Create", systemImage: "plus.circle").tag(NavDest.create)
                Divider()
                Label("Settings", systemImage: "gear").tag(NavDest.settings)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .navigationTitle("BaumAgent")
        } detail: {
            switch selection {
            case .tasks: TaskListView(onSelectTask: { id in selection = .taskDetail(id) })
            case .create: TaskCreateView(onCreated: { id in selection = .taskDetail(id) })
            case .settings: SettingsView()
            case .taskDetail(let id): TaskDetailView(taskId: id)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
