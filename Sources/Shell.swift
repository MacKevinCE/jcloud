import Foundation

enum Shell {

    @discardableResult
    static func run(_ command: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw JCloudError.commandFailed(output)
        }

        return output
    }

    static func extractVersion(from tool: String) -> String? {
        guard let output = try? run(tool, ["--version"]) else { return nil }
        // Output format: "tool 1.2.3"
        let parts = output.split(separator: " ")
        return parts.count >= 2 ? String(parts.last!) : nil
    }

    static func extractId(from output: String) -> String {
        output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .last ?? ""
    }
}
