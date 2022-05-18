import Vapor

struct StatusResponse: Content {
    var name: String
    var capabilities: [String]
}
