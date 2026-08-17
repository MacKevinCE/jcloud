import Foundation

struct ChannelData: Codable {
    var slots: [String: SlotEntry]
}

struct SlotEntry: Codable {
    let id: String
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
        let empty = ChannelData(slots: [:])
        let json = String(data: try JSONEncoder().encode(empty), encoding: .utf8)!
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

    static func updateSlot(_ slot: String, id: String) throws {
        guard let channelId = readLocal() else {
            throw JCloudError.noChannel
        }

        var channel: ChannelData
        do {
            channel = try readRemote()
        } catch {
            channel = ChannelData(slots: [:])
        }

        let formatter = ISO8601DateFormatter()
        channel.slots[slot] = SlotEntry(id: id, timestamp: formatter.string(from: Date()))

        let json = String(data: try JSONEncoder().encode(channel), encoding: .utf8)!
        try JsonEditorAPI.update(id: channelId, content: json)
    }

    static func getSlot(_ slot: String) throws -> String {
        let channel = try readRemote()
        guard let entry = channel.slots[slot] else {
            throw JCloudError.noSlotInChannel(slot)
        }
        return entry.id
    }
}
