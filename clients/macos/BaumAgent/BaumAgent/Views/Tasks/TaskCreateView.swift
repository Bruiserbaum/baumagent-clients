import SwiftUI
import Speech

struct TaskCreateView: View {
    var onCreated: (String) -> Void

    @State private var description = ""
    @State private var taskType = "research"
    @State private var model = "claude-opus-4-6"
    @State private var repoUrl = ""
    @State private var baseBranch = "main"
    @State private var loading = false
    @State private var listening = false
    @State private var voiceStatus = ""
    @State private var error: String?

    private let taskTypes: [(String, String)] = [
        ("research", "Research"),
        ("deep_research", "Deep Research"),
        ("code", "Code (GitHub)"),
        ("structured_document", "Structured Document"),
    ]

    private let models = [
        "claude-opus-4-6",
        "claude-sonnet-4-6",
        "claude-haiku-4-5-20251001",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create Task").font(.title2).bold()

                // Description
                GroupBox("Description") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $description)
                            .font(.body)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))
                        HStack {
                            Button(listening ? "Stop" : "🎤 Dictate") { toggleDictation() }
                                .disabled(loading)
                            if !voiceStatus.isEmpty {
                                Text(voiceStatus).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Task type + model
                GroupBox {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Task type").font(.caption).foregroundStyle(.secondary)
                            Picker("", selection: $taskType) {
                                ForEach(taskTypes, id: \.0) { Text($1).tag($0) }
                            }
                            .pickerStyle(.menu).labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LLM model").font(.caption).foregroundStyle(.secondary)
                            Picker("", selection: $model) {
                                ForEach(models, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu).labelsHidden()
                        }
                    }
                }

                // Code options
                if taskType == "code" {
                    GroupBox("Repository") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("https://github.com/…", text: $repoUrl)
                                .textFieldStyle(.roundedBorder)
                            TextField("Base branch (default: main)", text: $baseBranch)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let err = error {
                    Text(err).foregroundStyle(.red).font(.caption)
                }

                Button("Create task →") { Task { await submit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(loading || description.trimmingCharacters(in: .whitespaces).isEmpty)

                if loading { ProgressView() }
            }
            .padding(20)
        }
        .navigationTitle("Create Task")
    }

    private func toggleDictation() {
        if listening {
            SFSpeechRecognizer.shared?.stopListening()
            listening = false
            voiceStatus = ""
        } else {
            Task { await startDictation() }
        }
    }

    private func startDictation() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
            }
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            voiceStatus = "Microphone access denied"
            return
        }

        listening = true
        voiceStatus = "Listening…"

        do {
            let result = try await SFSpeechRecognizer.shared?.dictate()
            if let text = result, !text.isEmpty {
                description += text
            }
            voiceStatus = "Done"
        } catch {
            voiceStatus = "Error: \(error.localizedDescription)"
        }
        listening = false
    }

    private func submit() async {
        let desc = description.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty else { return }
        if taskType == "code" && repoUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            error = "Repository URL is required for code tasks."; return
        }
        error = nil; loading = true
        do {
            let task = try await APIService.shared.createTask(
                description: desc, taskType: taskType, llmModel: model,
                repoUrl: taskType == "code" ? repoUrl : "",
                baseBranch: taskType == "code" ? baseBranch : "main")
            description = ""; repoUrl = ""; baseBranch = "main"
            onCreated(task.id)
        } catch {
            self.error = "Failed: \(error.localizedDescription)"
        }
        loading = false
    }
}

// MARK: - SFSpeechRecognizer helpers

import Speech

extension SFSpeechRecognizer {
    static var shared: SFSpeechRecognizer? = SFSpeechRecognizer(locale: .current)

    func dictate() async throws -> String? {
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false

        let node = engine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in request.append(buf) }
        engine.prepare()
        try engine.start()

        return try await withCheckedThrowingContinuation { cont in
            recognitionTask(with: request) { result, error in
                if let error { engine.stop(); node.removeTap(onBus: 0); cont.resume(throwing: error); return }
                if let result, result.isFinal {
                    engine.stop(); node.removeTap(onBus: 0)
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    func stopListening() {
        // Handled via task cancellation in production; placeholder here
    }
}
