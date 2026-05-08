import Foundation

final class WebSocketService {
    func stream(taskId: String, token: String, baseUrl: String) -> AsyncStream<WsFrame> {
        AsyncStream { continuation in
            Task {
                var delay: UInt64 = 1_000_000_000 // 1 second in nanoseconds
                let wsUrl = baseUrl
                    .replacingOccurrences(of: "https://", with: "wss://")
                    .replacingOccurrences(of: "http://", with: "ws://")
                    .trimmingCharacters(in: .init(charactersIn: "/"))
                let urlString = "\(wsUrl)/ws/tasks/\(taskId)/logs?token=\(token)"
                guard let url = URL(string: urlString) else { continuation.finish(); return }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                while !Task.isCancelled {
                    let task = URLSession.shared.webSocketTask(with: url)
                    task.resume()
                    delay = 1_000_000_000

                    receiveLoop: while !Task.isCancelled {
                        do {
                            let msg = try await task.receive()
                            if case .string(let text) = msg, let data = text.data(using: .utf8) {
                                let frame = try decoder.decode(WsFrame.self, from: data)
                                continuation.yield(frame)
                                if frame.type == "done" || frame.type == "error" {
                                    task.cancel(with: .normalClosure, reason: nil)
                                    continuation.finish()
                                    return
                                }
                            }
                        } catch {
                            break receiveLoop
                        }
                    }

                    task.cancel(with: .abnormalClosure, reason: nil)
                    try? await Task.sleep(nanoseconds: delay)
                    delay = min(delay * 2, 30_000_000_000)
                }
                continuation.finish()
            }
        }
    }
}
