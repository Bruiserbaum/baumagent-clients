import Foundation

// MARK: - Task

struct BaumTask: Codable, Identifiable {
    let id: String
    let description: String
    let taskType: String
    let status: String
    let llmBackend: String
    let llmModel: String
    let repoUrl: String?
    let prUrl: String?
    let prNumber: Int?
    let outputFile: String?
    let log: String?
    let progressPercent: Int?
    let createdAt: Date
    let updatedAt: Date
    let projectId: String?

    var isTerminal: Bool { ["complete", "failed", "cancelled"].contains(status) }
    var isRunning: Bool { status == "running" }

    enum CodingKeys: String, CodingKey {
        case id, description, status, log
        case taskType = "task_type"
        case llmBackend = "llm_backend"
        case llmModel = "llm_model"
        case repoUrl = "repo_url"
        case prUrl = "pr_url"
        case prNumber = "pr_number"
        case outputFile = "output_file"
        case progressPercent = "progress_percent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case projectId = "project_id"
    }
}

struct TaskListResponse: Codable {
    let items: [BaumTask]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}

// MARK: - Export

struct ExportFile: Codable, Identifiable {
    let filename: String
    let sizeBytes: Int
    let downloadUrl: String

    var id: String { filename }

    var sizeDisplay: String {
        if sizeBytes < 1024 { return "\(sizeBytes) B" }
        if sizeBytes < 1_048_576 { return String(format: "%.1f KB", Double(sizeBytes) / 1024) }
        return String(format: "%.1f MB", Double(sizeBytes) / 1_048_576)
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case sizeBytes = "size_bytes"
        case downloadUrl = "download_url"
    }
}

// MARK: - Queue

struct QueueStatus: Codable {
    let queued: [String]
    let running: [String]
}

// MARK: - Auth / pairing

struct PairCompleteResponse: Codable {
    let token: String
    let userId: String
    let userEmail: String
    let userDisplayName: String

    enum CodingKeys: String, CodingKey {
        case token
        case userId = "user_id"
        case userEmail = "user_email"
        case userDisplayName = "user_display_name"
    }
}

struct ApiToken: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    let lastUsedAt: Date?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case expiresAt = "expires_at"
    }
}

// MARK: - WebSocket frame

struct WsFrame: Decodable {
    let type: String
    let data: WsData
}

enum WsData: Decodable {
    case string(String)
    case int(Int)
    case done(WsDonePayload)
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let i = try? container.decode(Int.self) { self = .int(i); return }
        if let d = try? container.decode(WsDonePayload.self) { self = .done(d); return }
        self = .unknown
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var intValue: Int? { if case .int(let i) = self { return i }; return nil }
    var donePayload: WsDonePayload? { if case .done(let d) = self { return d }; return nil }
}

struct WsDonePayload: Decodable {
    let status: String
    let outputFile: String?
    let prUrl: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case status, error
        case outputFile = "output_file"
        case prUrl = "pr_url"
    }
}

// MARK: - Health

struct HealthResponse: Decodable {
    let status: String
    let version: String?
}
