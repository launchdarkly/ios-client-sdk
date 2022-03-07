import Foundation

public struct ConnectionInformation: Codable, CustomStringConvertible {
    public enum ConnectionMode: String, Codable {
        case streaming, offline, establishingStreamingConnection, polling
    }

    public enum LastConnectionFailureReason: Codable, CustomStringConvertible {
        public var description: String {
            switch self {
            case .unauthorized:
                return "unauthorized"
            case .none:
                return "none"
            case .httpError:
                return "httpError: " + String(self.httpValue ?? Constants.noCode)
            case .unknownError:
                return "unknownError: " + (self.unknownValue ?? Constants.unknownError)
            }
        }

        case unauthorized, httpError(Int), unknownError(String), none // We need .none for a non-failable initializer to conform to Codable

        var unknownValue: String? {
            guard case let .unknownError(value) = self
            else { return nil }
            return value
        }

        var httpValue: Int? {
            guard case let .httpError(value) = self
            else { return nil }
            return value
        }
    }

    public struct Constants {
        static let noCode: Int = 0
        static let unknownError: String = "Unknown Error"
        static let decodeError: String =  "Unable to Decode error."
    }

    // lastKnownFlagValidity is nil if either no connection has ever been successfully made or if the SDK has an active streaming connection. It will have a value if 1) in polling mode and at least one poll has completed successfully, or 2) if in streaming mode whenever the streaming connection closes.
    public internal(set) var lastKnownFlagValidity: Date?
    public internal(set) var lastFailedConnection: Date?
    public internal(set) var currentConnectionMode: ConnectionMode
    public internal(set) var lastConnectionFailureReason: LastConnectionFailureReason

    init(currentConnectionMode: ConnectionMode, lastConnectionFailureReason: LastConnectionFailureReason, lastKnownFlagValidity: Date? = nil, lastFailedConnection: Date? = nil) {
        self.currentConnectionMode = currentConnectionMode
        self.lastConnectionFailureReason = lastConnectionFailureReason
        self.lastKnownFlagValidity = lastKnownFlagValidity
        self.lastFailedConnection = lastFailedConnection
    }

    // Returns ConnectionInformation as a prettyfied string
    public var description: String {
        var connInfoString: String = ""
        connInfoString.append("Current Connection Mode: \(currentConnectionMode.rawValue) | ")
        connInfoString.append("Last Connection Failure Reason: \(lastConnectionFailureReason.description) | ")
        connInfoString.append("Last Successful Connection: \(lastKnownFlagValidity?.debugDescription ?? "NONE") | ")
        connInfoString.append("Last Failed Connection: \(lastFailedConnection?.debugDescription ?? "NONE")")
        return connInfoString
    }

    // Restores ConnectionInformation from UserDefaults if it exists
    static func uncacheConnectionInformation(config: LDConfig, ldClient: LDClient, clientServiceFactory: ClientServiceCreating) -> ConnectionInformation {
        var connectionInformation = ConnectionInformationStore.retrieveStoredConnectionInformation() ?? clientServiceFactory.makeConnectionInformation()
        connectionInformation = onlineSetCheck(connectionInformation: connectionInformation, ldClient: ldClient, config: config, online: ldClient.isOnline)
        return connectionInformation
    }

    // Used for updating lastSuccessfulConnection when connected to streaming and connection closes
    static func lastSuccessfulConnectionCheck(connectionInformation: ConnectionInformation) -> ConnectionInformation {
        var connectionInformationVar = connectionInformation
        if connectionInformationVar.currentConnectionMode == .streaming {
            connectionInformationVar.lastKnownFlagValidity = Date()
        }
        return connectionInformationVar
    }

    // Used for updating ConnectionInformation inside of LDClient.setOnline
    static func onlineSetCheck(connectionInformation: ConnectionInformation, ldClient: LDClient, config: LDConfig, online: Bool) -> ConnectionInformation {
        var connectionInformationVar = connectionInformation
        if online && NetworkReporter.isConnectedToNetwork() {
            connectionInformationVar.currentConnectionMode = effectiveStreamingMode(config: config, ldClient: ldClient) == LDStreamingMode.streaming ? .establishingStreamingConnection : .polling
        } else {
            connectionInformationVar.currentConnectionMode = .offline
        }
        return connectionInformationVar
    }

    // Used for parsing SynchronizingError in LDClient.process
    static func synchronizingErrorCheck(synchronizingError: SynchronizingError, connectionInformation: ConnectionInformation) -> ConnectionInformation {
        var connectionInformationVar = connectionInformation
        if synchronizingError.isClientUnauthorized {
            connectionInformationVar.lastConnectionFailureReason = .unauthorized
        } else {
            switch synchronizingError {
            case .request(let error):
                let errorString = error.localizedDescription.isEmpty ? Constants.unknownError : error.localizedDescription
                connectionInformationVar.lastConnectionFailureReason = .unknownError(errorString)
            case .response(let urlResponse):
                let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode
                connectionInformationVar.lastConnectionFailureReason = .httpError(statusCode ?? ConnectionInformation.Constants.noCode)
            default: break
            }
        }
        connectionInformationVar.lastFailedConnection = Date()
        return connectionInformationVar
    }
    
    // This function is used to ensure we switch from establishing a streaming connection to streaming once we are connected.
    static func checkEstablishingStreaming(connectionInformation: ConnectionInformation) -> ConnectionInformation {
        var connectionInformationVar = connectionInformation
        if connectionInformationVar.currentConnectionMode == .establishingStreamingConnection {
            connectionInformationVar.currentConnectionMode = .streaming
            connectionInformationVar.lastKnownFlagValidity = nil
        }
        if connectionInformationVar.currentConnectionMode == .polling {
            connectionInformationVar.lastKnownFlagValidity = Date()
        }
        return connectionInformationVar
    }

    static func effectiveStreamingMode(config: LDConfig, ldClient: LDClient) -> LDStreamingMode {
        var reason = ""
        let streamingMode: LDStreamingMode = ldClient.isInSupportedRunMode && config.streamingMode == .streaming && config.allowStreamingMode ? .streaming : .polling
        if config.streamingMode == .streaming && !ldClient.isInSupportedRunMode {
            reason = " LDClient is in background mode with background updates disabled."
        }
        if reason.isEmpty && config.streamingMode == .streaming && !config.allowStreamingMode {
            reason = " LDConfig disallowed streaming mode. "
            reason += !ldClient.environmentReporter.operatingSystem.isStreamingEnabled ? "Streaming is not allowed on \(ldClient.environmentReporter.operatingSystem)." : "Unknown reason."
        }
        Log.debug(ldClient.typeName(and: #function, appending: ": ") + "\(streamingMode)\(reason)")
        return streamingMode
    }

    static func backgroundBehavior(connectionInformation: ConnectionInformation, streamingMode: LDStreamingMode, goOnline: Bool) -> ConnectionInformation {
        var connectionInformationVar = connectionInformation
        if !goOnline {
            connectionInformationVar.currentConnectionMode = .offline
        } else if streamingMode == .streaming {
            connectionInformationVar.currentConnectionMode = .establishingStreamingConnection
        } else if streamingMode == .polling {
            connectionInformationVar.currentConnectionMode = .polling
        }
        return connectionInformationVar
    }
}

extension ConnectionInformation.LastConnectionFailureReason {
    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    /// Decode a ConnectionInformation.LastConnectionFailureReason enum using Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "unknownError":
            let payload = try? container.decode(String.self, forKey: .payload)
            self = .unknownError(payload ?? ConnectionInformation.Constants.decodeError)
        case "httpError":
            let payload = try? container.decode(Int.self, forKey: .payload)
            self = .httpError(payload ?? ConnectionInformation.Constants.noCode)
        case "unauthorized":
            self = .unauthorized
        default:
            self = .none
        }
    }

    /// Encode a ConnectionInformation.LastConnectionFailureReason enum using Codable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .unknownError(let error):
            try container.encode("unknownError", forKey: .type)
            try container.encode(error, forKey: .payload)
        case .httpError(let code):
            try container.encode("httpError", forKey: .type)
            try container.encode(code, forKey: .payload)
        case .unauthorized:
            try container.encode("unauthorized", forKey: .type)
        case .none:
            try container.encode("none", forKey: .type)
        }
    }
}
