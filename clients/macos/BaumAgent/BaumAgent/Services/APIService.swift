import Foundation

enum APIError: LocalizedError {
    case httpError(Int, String)
    case decodingError(Error)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let e): return "Decoding error: \(e)"
        case .notConfigured: return "Not paired with a server."
        }
    }
}

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()

    private let keychain = KeychainService.shared
    private var session = URLSession.shared

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func baseURL() throws -> URL {
        guard let creds = keychain.load(), !creds.url.isEmpty else { throw APIError.notConfigured }
        var s = creds.url
        if !s.hasSuffix("/") { s += "/" }
        return URL(string: s)!
    }

    private func authedRequest(_ path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let creds = keychain.load() else { throw APIError.notConfigured }
        let url = try baseURL().appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, msg)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Health

    func checkHealth(url: String) async throws -> HealthResponse {
        var base = url; if !base.hasSuffix("/") { base += "/" }
        let req = URLRequest(url: URL(string: base + "api/health")!)
        return try await perform(req)
    }

    // MARK: - Pairing

    func completePairing(url: String, code: String, deviceName: String) async throws -> PairCompleteResponse {
        var base = url; if !base.hasSuffix("/") { base += "/" }
        var req = URLRequest(url: URL(string: base + "api/auth/pair/complete")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["code": code, "device_name": deviceName])
        return try await perform(req)
    }

    // MARK: - Tokens

    func listTokens() async throws -> [ApiToken] {
        return try await perform(try authedRequest("api/auth/tokens"))
    }

    func revokeToken(id: String) async throws {
        var req = try authedRequest("api/auth/tokens/\(id)", method: "DELETE")
        let (_, _) = try await session.data(for: req)
    }

    // MARK: - Push

    func registerPushToken(token: String, deviceLabel: String) async throws {
        let body = try JSONEncoder().encode(["platform": "apns", "token": token, "device_label": deviceLabel])
        var req = try authedRequest("api/push/register", method: "POST", body: body)
        let (_, _) = try await session.data(for: req)
    }

    // MARK: - Tasks

    func listTasks(page: Int = 1, pageSize: Int = 25) async throws -> TaskListResponse {
        let path = "api/tasks?page=\(page)&page_size=\(pageSize)"
        return try await perform(try authedRequest(path))
    }

    func getTask(id: String) async throws -> BaumTask {
        return try await perform(try authedRequest("api/tasks/\(id)"))
    }

    func createTask(
        description: String,
        taskType: String,
        llmModel: String,
        repoUrl: String = "",
        baseBranch: String = "main"
    ) async throws -> BaumTask {
        guard let creds = keychain.load() else { throw APIError.notConfigured }
        let url = try baseURL().appendingPathComponent("api/tasks")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        addField("description", description)
        addField("task_type", taskType)
        addField("llm_backend", "anthropic")
        addField("llm_model", llmModel)
        addField("repo_url", repoUrl)
        addField("base_branch", baseBranch)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        return try await perform(req)
    }

    func retryTask(id: String) async throws -> BaumTask {
        return try await perform(try authedRequest("api/tasks/\(id)/retry", method: "POST"))
    }

    func cancelTask(id: String) async throws {
        var req = try authedRequest("api/tasks/\(id)/cancel", method: "POST")
        let (_, _) = try await session.data(for: req)
    }

    func listExports(taskId: String) async throws -> [ExportFile] {
        return try await perform(try authedRequest("api/tasks/\(taskId)/exports"))
    }

    // MARK: - Queue

    func getQueue() async throws -> QueueStatus {
        return try await perform(try authedRequest("api/queue"))
    }
}
