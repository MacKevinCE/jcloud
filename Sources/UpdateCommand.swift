import Foundation

enum UpdateCommand {

    static func run() throws {
        let channel = try Channel.readRemote()

        guard let publish = channel.publish else {
            print("No published binaries in channel.")
            return
        }

        // Check which tools need updating
        var toUpdate: [(String, String, String)] = [] // (name, localVer, remoteVer)
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

        // Download the bundle
        let tempDir = "\(NSTemporaryDirectory())jcloud_update_\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        print("\nDownloading...")
        _ = try Shell.run("b2c", ["download", publish.id, "-o", tempDir])

        // Find and install binaries
        let fm = FileManager.default
        let toolNames = Set(toUpdate.map { $0.0 })
        let enumerator = fm.enumerator(atPath: tempDir)

        while let file = enumerator?.nextObject() as? String {
            let fullPath = "\(tempDir)/\(file)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            if isDir.boolValue { continue }

            let fileName = URL(fileURLWithPath: file).lastPathComponent
            guard toolNames.contains(fileName) else { continue }

            let destPath = "/usr/local/bin/\(fileName)"
            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(atPath: destPath)
            }
            try fm.copyItem(atPath: fullPath, toPath: destPath)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destPath)
            print("  Installed: \(fileName)")
        }

        print("\nDone!")
        for (tool, _, remote) in toUpdate {
            print("  \(tool) v\(remote)")
        }
    }
}
