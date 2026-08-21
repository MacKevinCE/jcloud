import Foundation

enum UpdateCommand {

    static func run() throws {
        let channel = try Channel.readRemote()

        // Use new per-tool format if available, fallback to legacy bundle
        if let publishTools = channel.publishTools, !publishTools.isEmpty {
            try updatePerTool(publishTools)
        } else if let publish = channel.publish {
            try updateLegacyBundle(publish)
        } else {
            print("No published binaries in channel.")
        }
    }

    // MARK: - Per-tool update (new format)

    private static func updatePerTool(_ publishTools: [String: ToolPublishEntry]) throws {
        var toUpdate: [(name: String, localVer: String, remoteVer: String, id: String)] = []

        for (tool, entry) in publishTools {
            let localVer = Shell.extractVersion(from: tool) ?? "0.0.0"
            if Channel.compareVersions(entry.version, isGreaterThan: localVer) {
                toUpdate.append((tool, localVer, entry.version, entry.id))
            }
        }

        if toUpdate.isEmpty {
            print("All tools are up to date.")
            return
        }

        print("Updates available:")
        for item in toUpdate.sorted(by: { $0.name < $1.name }) {
            print("  \(item.name)  \(item.localVer) → \(item.remoteVer)")
        }

        let fallbackDir = Shell.jcloudBinDir()

        for item in toUpdate.sorted(by: { $0.name < $1.name }) {
            let tempDir = "\(NSTemporaryDirectory())jcloud_upd_\(item.name)_\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: tempDir) }

            print("\nDownloading \(item.name)...")
            _ = try Shell.run("b2c", ["download", item.id, "-o", tempDir])

            let destPath = Shell.which(item.name) ?? "\(fallbackDir)/\(item.name)"
            try installBinary(from: tempDir, name: item.name, to: destPath)
            print("  Installed: \(destPath)")
        }

        print("\nDone!")
        for item in toUpdate.sorted(by: { $0.name < $1.name }) {
            print("  \(item.name) v\(item.remoteVer)")
        }
    }

    // MARK: - Legacy bundle update (backwards compatible)

    private static func updateLegacyBundle(_ publish: PublishData) throws {
        var toUpdate: [(String, String, String)] = []
        for (tool, remoteVer) in publish.tools {
            let localVer = Shell.extractVersion(from: tool) ?? "0.0.0"
            if Channel.compareVersions(remoteVer, isGreaterThan: localVer) {
                toUpdate.append((tool, localVer, remoteVer))
            }
        }

        if toUpdate.isEmpty {
            print("All tools are up to date.")
            return
        }

        print("Updates available:")
        for (tool, local, remote) in toUpdate {
            print("  \(tool)  \(local) → \(remote)")
        }

        let tempDir = "\(NSTemporaryDirectory())jcloud_update_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        print("\nDownloading bundle...")
        _ = try Shell.run("b2c", ["download", publish.id, "-o", tempDir])

        let fallbackDir = Shell.jcloudBinDir()
        let toolNames = Set(toUpdate.map { $0.0 })
        let enumerator = FileManager.default.enumerator(atPath: tempDir)

        while let file = enumerator?.nextObject() as? String {
            let fullPath = "\(tempDir)/\(file)"
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
            if isDir.boolValue { continue }

            let fileName = URL(fileURLWithPath: file).lastPathComponent
            guard toolNames.contains(fileName) else { continue }

            let destPath = Shell.which(fileName) ?? "\(fallbackDir)/\(fileName)"
            try installBinary(from: tempDir, name: fileName, to: destPath)
            print("  Installed: \(destPath)")
        }

        print("\nDone!")
        for (tool, _, remote) in toUpdate {
            print("  \(tool) v\(remote)")
        }
    }

    // MARK: - Shared

    private static func installBinary(from dir: String, name: String, to destPath: String) throws {
        let fm = FileManager.default
        let enumerator = fm.enumerator(atPath: dir)
        while let file = enumerator?.nextObject() as? String {
            let fullPath = "\(dir)/\(file)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            if isDir.boolValue { continue }

            let fileName = URL(fileURLWithPath: file).lastPathComponent
            guard fileName == name else { continue }

            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(atPath: destPath)
            }
            try fm.copyItem(atPath: fullPath, toPath: destPath)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)

            // Ad-hoc sign binaries (required on macOS for locally compiled tools)
            _ = try? Shell.run("codesign", ["--sign", "-", "--force", destPath])

            return
        }
    }
}
