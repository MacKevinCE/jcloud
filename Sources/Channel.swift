import Foundation

struct ChannelData: Codable {
    var slots: [String: SlotEntry]
    var versions: [String: String]?
    var publish: PublishData?
}

struct SlotEntry: Codable {
    let id: String
    let timestamp: String
}

struct PublishData: Codable {
    let id: String
    let tools: [String: String]
    let timestamp: String
}

enum Channel {

    private static let configDir = "\(NSHomeDirectory())/.config/b2c-gsync"
    private static let configFile = "\(configDir)/channel"

    // MARK: - Local config

    static func readLocal() -> String? {
        guard let content = try? String(contentsOfFile: configFile, encoding: .utf8) else {
            return nil
        }
        let id = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }

    static func writeLocal(_ channelId: String) throws {
        try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        try channelId.write(toFile: configFile, atomically: true, encoding: .utf8)
    }

    static func clearLocal() throws {
        try? FileManager.default.removeItem(atPath: configFile)
    }

    // MARK: - Remote channel

    static func create() throws -> String {
        let empty = ChannelData(slots: [:], versions: [:], publish: nil)
        guard let json = String(data: try JSONEncoder().encode(empty), encoding: .utf8) else {
            throw JCloudError.invalidResponse
        }
        let id = try JsonEditorAPI.create(name: "b2c-gsync.channel", content: json)
        try writeLocal(id)
        return id
    }

    static func readRemote() throws -> ChannelData {
        guard let channelId = readLocal() else {
            throw JCloudError.noChannel
        }
        let raw = try JsonEditorAPI.read(id: channelId)
        guard let data = raw.data(using: .utf8),
              let channel = try? JSONDecoder().decode(ChannelData.self, from: data) else {
            throw JCloudError.invalidChannel
        }
        return channel
    }

    static func writeRemote(_ channel: ChannelData) throws {
        guard let channelId = readLocal() else {
            throw JCloudError.noChannel
        }
        guard let json = String(data: try JSONEncoder().encode(channel), encoding: .utf8) else {
            throw JCloudError.invalidResponse
        }
        try JsonEditorAPI.update(id: channelId, content: json)
    }

    static func updateSlot(_ slot: String, id: String, toolName: String? = nil, toolVersion: String? = nil, extraVersions: [String: String]? = nil) throws {
        var channel: ChannelData
        do {
            channel = try readRemote()
        } catch {
            channel = ChannelData(slots: [:], versions: [:], publish: nil)
        }

        let formatter = ISO8601DateFormatter()
        channel.slots[slot] = SlotEntry(id: id, timestamp: formatter.string(from: Date()))

        // Update versions
        if channel.versions == nil { channel.versions = [:] }
        if let name = toolName, let ver = toolVersion {
            if let current = channel.versions?[name] {
                if compareVersions(ver, isGreaterThan: current) {
                    channel.versions?[name] = ver
                }
            } else {
                channel.versions?[name] = ver
            }
        }
        if let extras = extraVersions {
            for (name, ver) in extras {
                if let current = channel.versions?[name] {
                    if compareVersions(ver, isGreaterThan: current) {
                        channel.versions?[name] = ver
                    }
                } else {
                    channel.versions?[name] = ver
                }
            }
        }

        try writeRemote(channel)
    }

    static func getSlot(_ slot: String) throws -> String {
        let channel = try readRemote()
        guard let entry = channel.slots[slot] else {
            throw JCloudError.noSlotInChannel(slot)
        }
        return entry.id
    }

    // MARK: - Version comparison

    static func compareVersions(_ a: String, isGreaterThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal > bVal { return true }
            if aVal < bVal { return false }
        }
        return false
    }

    static func checkTools(_ toolSpecs: String, channelVersions: [String: String]) -> [(String, String, String)] {
        var outdated: [(String, String, String)] = [] // (name, local, remote)

        let pairs = toolSpecs.split(separator: ",")
        for pair in pairs {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = String(parts[0])
            let localVer = String(parts[1])
            if let remoteVer = channelVersions[name],
               compareVersions(remoteVer, isGreaterThan: localVer) {
                outdated.append((name, localVer, remoteVer))
            }
        }

        return outdated
    }
}
