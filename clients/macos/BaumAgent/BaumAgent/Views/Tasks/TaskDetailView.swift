import SwiftUI

struct TaskDetailView: View {
    let taskId: String

    @State private var task: BaumTask?
    @State private var liveStatus = ""
    @State private var log = ""
    @State private var progress: Int?
    @State private var exports: [ExportFile] = []
    @State private var error: String?
    @State private var wsTask: Task<Void, Never>?

    private let ws = WebSocketService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let task {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.description).font(.headline).fontWeight(.bold)
                        HStack(spacing: 12) {
                            StatusBadge(status: liveStatus)
                            Text(task.taskType).font(.caption).foregroundStyle(.secondary)
                            Text(task.llmModel).font(.caption).foregroundStyle(.secondary)
                        }
                        if let pct = progress {
                            ProgressView(value: Double(pct), total: 100)
                        }
                        if let prUrl = task.prUrl, let url = URL(string: prUrl) {
                            Link("PR #\(task.prNumber ?? 0) →", destination: url)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.top, 8)
            }

            // Action buttons
            HStack(spacing: 8) {
                Button("Cancel") { Task { await cancel() } }
                    .disabled(task == nil || task!.isTerminal)
                Button("↻ Re-run") { Task { await retry() } }
                    .disabled(task == nil || !task!.isTerminal)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            Divider()

            // Log
            ScrollViewReader { proxy in
                ScrollView {
                    Text(log.isEmpty ? "Connecting…" : log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("bottom")
                }
                .background(Color(red: 0.06, green: 0.09, blue: 0.16))
                .onChange(of: log) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            // Exports
            if !exports.isEmpty {
                Divider()
                GroupBox("Exports") {
                    ForEach(exports) { export in
                        HStack {
                            Text(export.filename).font(.caption)
                            Text(export.sizeDisplay).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if let url = URL(string: export.downloadUrl) {
                                Link("Download", destination: url).font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
        .navigationTitle("Task")
        .task { await loadTask() }
        .onDisappear { wsTask?.cancel() }
    }

    private func loadTask() async {
        do {
            let t = try await APIService.shared.getTask(id: taskId)
            task = t
            liveStatus = t.status
            log = t.log ?? ""
            if t.isTerminal {
                await loadExports()
            } else {
                startStream(t)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startStream(_ t: BaumTask) {
        guard let creds = KeychainService.shared.load() else { return }
        wsTask?.cancel()
        wsTask = Task {
            for await frame in ws.stream(taskId: taskId, token: creds.token, baseUrl: creds.url) {
                await MainActor.run {
                    switch frame.type {
                    case "log": log += frame.data.stringValue ?? ""
                    case "status": liveStatus = frame.data.stringValue ?? liveStatus
                    case "progress": progress = frame.data.intValue
                    case "done":
                        progress = nil
                        if let done = frame.data.donePayload {
                            liveStatus = done.status
                            if done.status == "complete" {
                                Task { await loadExports() }
                            }
                        }
                    default: break
                    }
                }
                if frame.type == "done" || frame.type == "error" { break }
            }
        }
    }

    private func loadExports() async {
        do { exports = try await APIService.shared.listExports(taskId: taskId) } catch {}
    }

    private func cancel() async {
        do { try await APIService.shared.cancelTask(id: taskId); liveStatus = "cancelled" } catch {}
    }

    private func retry() async {
        do {
            let t = try await APIService.shared.retryTask(id: taskId)
            task = t; liveStatus = t.status; log = ""; progress = nil; exports = []
            startStream(t)
        } catch {}
    }
}
