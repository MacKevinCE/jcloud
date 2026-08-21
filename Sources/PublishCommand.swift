import Foundation

enum PublishCommand {

    static func run(tools: [String]) throws {
        // Verify all binaries exist and get versions
        var toolVersions: [String: String] = [:]
        var toolPaths: [String: String] = [:]

        for tool in tools {
            guard let path = Shell.which(tool) else {
                throw JCloudError.toolNotFound(tool)
            }
            guard let ver = Shell.extractVersion(from: tool) else {
                throw JCloudError.commandFailed("Could not get version for \(tool)")
            }
            toolPaths[tool] = path
            toolVersions[tool] = ver
        }

        // Read current channel
        var channel: ChannelData
        do {
            channel = try Channel.readRemote()
        } catch {
            channel = ChannelData(slots: [:], versions: [:], publish: nil, publishTools: [:])
        }

        if channel.publishTools == nil { channel.publishTools = [:] }
        if channel.versions == nil { channel.versions = [:] }

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())

        // Publish each tool individually
        print("Uploading \(tools.count) binary(ies)...")
        for tool in tools.sorted() {
            guard let path = toolPaths[tool], let ver = toolVersions[tool] else { continue }

            // Create temp dir with single binary
            let tempDir = "\(NSTemporaryDirectory())jcloud_pub_\(tool)_\(UUID().uuidString)"
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            try FileManager.default.copyItem(atPath: path, toPath: "\(tempDir)/\(tool)")

            // Reuse previous ID if available
            var reuseArgs: [String] = []
            if let existing = channel.publishTools?[tool] {
                reuseArgs = ["--reuse", existing.id]
            }

            let output = try Shell.run("b2c", ["upload", tempDir, "-y", "--no-channel"] + reuseArgs)
            let indexId = Shell.extractId(from: output)

            guard !indexId.isEmpty else {
                throw JCloudError.commandFailed("Failed to get upload ID for \(tool)")
            }

            channel.publishTools?[tool] = ToolPublishEntry(id: indexId, version: ver, timestamp: timestamp)
            channel.versions?[tool] = ver
            print("  \(tool) v\(ver) → \(indexId)")
        }

        try Channel.writeRemote(channel)

        print("\nPublished:")
        for tool in tools.sorted() {
            if let ver = toolVersions[tool] {
                print("  \(tool) v\(ver)")
            }
        }
        print("\nOn the other machine, run: jcloud update")
    }
}
