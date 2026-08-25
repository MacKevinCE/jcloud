import Foundation

// MARK: - Interactive Protocol
// Two-phase execution for hub integration:
// Phase 1: --interactive → JSON prompt or done
// Phase 2: --interactive --reply <value> → complete with cached state

enum InteractiveProtocol {

    private static let cacheDir = "\(NSHomeDirectory())/.cache/sync-tools"

    // MARK: - Response types

    struct Option: Codable {
        let value: String
        let label: String
    }

    struct Prompt: Codable {
        let status: String      // "prompt"
        let taskId: String
        let title: String
        let type: String        // "select" or "multi-select"
        let options: [Option]
    }

    struct Done: Codable {
        let status: String      // "done"
        let message: String
    }

    // MARK: - Output

    static func outputPrompt(taskId: String, title: String, type: String, options: [Option]) {
        let prompt = Prompt(status: "prompt", taskId: taskId, title: title, type: type, options: options)
        if let data = try? JSONEncoder().encode(prompt),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    static func outputDone(message: String) {
        let done = Done(status: "done", message: message)
        if let data = try? JSONEncoder().encode(done),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    // MARK: - Cache

    static func saveCache(taskId: String, data: [String: String]) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
        let path = "\(cacheDir)/\(taskId).json"
        if let json = try? JSONSerialization.data(withJSONObject: data) {
            try? json.write(to: URL(fileURLWithPath: path))
        }
    }

    static func loadCache(taskId: String) -> [String: String]? {
        let path = "\(cacheDir)/\(taskId).json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return dict
    }

    static func clearCache(taskId: String) {
        let path = "\(cacheDir)/\(taskId).json"
        try? FileManager.default.removeItem(atPath: path)
    }
}
