import SwiftUI

struct TaskListView: View {
    var onSelectTask: (String) -> Void

    @State private var tasks: [BaumTask] = []
    @State private var queued = 0
    @State private var running = 0
    @State private var total = 0
    @State private var page = 1
    @State private var loading = false
    @State private var error: String?

    private let pageSize = 25
    private var totalPages: Int { max(1, Int(ceil(Double(total) / Double(pageSize)))) }

    var body: some View {
        VStack(spacing: 0) {
            // Queue status bar
            HStack(spacing: 16) {
                Label("Queued: \(queued)", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Running: \(running)", systemImage: "bolt.fill")
                    .font(.caption).foregroundStyle(.blue)
                Spacer()
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.bar)

            Divider()

            if loading && tasks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = error {
                Text(err).foregroundStyle(.red).padding()
            } else if tasks.isEmpty {
                Text("No tasks yet").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectTask(task.id) }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Pagination
            HStack(spacing: 8) {
                Button("← Prev") { Task { if page > 1 { page -= 1; await load() } } }
                    .disabled(page <= 1)
                Text("Page \(page) of \(totalPages)")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Next →") { Task { if page < totalPages { page += 1; await load() } } }
                    .disabled(page >= totalPages)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Tasks")
        .task { await load() }
    }

    private func load() async {
        loading = true; error = nil
        do {
            async let tasksReq = APIService.shared.listTasks(page: page, pageSize: pageSize)
            async let queueReq = APIService.shared.getQueue()
            let (resp, queue) = try await (tasksReq, queueReq)
            tasks = resp.items
            total = resp.total
            queued = queue.queued.count
            running = queue.running.count
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct TaskRowView: View {
    let task: BaumTask

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.description)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(task.taskType).font(.caption).foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: task.status)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "complete": .green
        case "failed": .red
        case "cancelled": .orange
        case "running": .blue
        default: .gray
        }
    }

    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}
