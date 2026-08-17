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

        // Create temp dir with binaries
        let tempDir = "\(NSTemporaryDirectory())jcloud_publish_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        for (tool, path) in toolPaths {
            try FileManager.default.copyItem(
                atPath: path,
                toPath: "\(tempDir)/\(tool)"
            )
        }

        print("Uploading \(tools.count) binary(ies)...")
        let output = try Shell.run("b2c", ["upload", tempDir, "-y", "--no-channel"])
        let indexId = Shell.extractId(from: output)

        guard !indexId.isEmpty else {
            throw JCloudError.commandFailed("Failed to get upload ID from b2c")
        }

        // Update channel
        var channel: ChannelData
        do {
            channel = try Channel.readRemote()
        } catch {
            channel = ChannelData(slots: [:], versions: [:], publish: nil)
        }

        let formatter = ISO8601DateFormatter()
        channel.publish = PublishData(
            id: indexId,
            tools: toolVersions,
            timestamp: formatter.string(from: Date())
        )

        if channel.versions == nil { channel.versions = [:] }
        for (tool, ver) in toolVersions {
            channel.versions?[tool] = ver
        }

        try Channel.writeRemote(channel)

        print("\nPublished:")
        for (tool, ver) in toolVersions.sorted(by: { $0.key < $1.key }) {
            print("  \(tool) v\(ver)")
        }
        print("\nOn the other machine, run: jcloud update")
    }
}
