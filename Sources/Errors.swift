import Foundation

enum JCloudError: Error, LocalizedError {
    case http(Int, String)
    case invalidResponse
    case missingField(String)
    case noChannel
    case invalidChannel
    case noSlotInChannel(String)
    case missingArgument(String)
    case toolNotFound(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body):
            return "HTTP \(code): \(body)"
        case .invalidResponse:
            return "Invalid server response"
        case .missingField(let field):
            return "Missing field: \(field)"
        case .noChannel:
            return "No channel configured. Run: jcloud channel create (or jcloud channel set <id>)"
        case .invalidChannel:
            return "Channel document is invalid or unreadable"
        case .noSlotInChannel(let slot):
            return "No '\(slot)' entry in channel. The other machine hasn't run that command yet."
        case .missingArgument(let arg):
            return "Missing argument: \(arg)"
        case .toolNotFound(let tool):
            return "Binary not found in PATH: \(tool)"
        case .commandFailed(let msg):
            return msg
        }
    }
}
