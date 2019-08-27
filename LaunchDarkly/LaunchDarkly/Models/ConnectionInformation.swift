//
//  ConnectionInformation.swift
//  LaunchDarkly_iOS
//
//  Created by Joe Cieslik on 8/13/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

public struct ConnectionInformation: Codable {
    public enum ConnectionMode: String, Codable {
        case streaming, offline, establishingStreamingConnection, polling
    }
    
    public enum LastConnectionFailureReason: Codable {
        case unauthorized, httpError(Int), unknownError(String), none //We need .none for a non-failable initializer to conform to Codable
        
        var unknownValue: String? {
            guard case let .unknownError(value) = self else { return nil }
            return value
        }
        
        var httpValue: Int? {
            guard case let .httpError(value) = self else { return nil }
            return value
        }
        
        func getValue() -> String {
            switch self {
            case .unauthorized:
                return "unauthorized"
            case .none:
                return "none"
            case .httpError:
                return String(self.httpValue ?? ConnectionInformation.Constants.noCode)
            case .unknownError:
                return self.unknownValue ?? ConnectionInformation.Constants.unknownError
            }
        }
    }
    
    public struct Constants {
        static let noCode: Int = 0
        static let unknownError: String = "Unknown Error"
        static let decodeError: String =  "Unable to Decode error."
    }
    
    public internal(set) var lastSuccessfulConnection: TimeInterval?
    public internal(set) var lastFailedConnection: TimeInterval?
    public internal(set) var currentConnectionMode: ConnectionMode
    public internal(set) var lastConnectionFailureReason: LastConnectionFailureReason
    
    init(currentConnectionMode: ConnectionMode, lastConnectionFailureReason: LastConnectionFailureReason, lastSuccessfulConnection: TimeInterval? = nil, lastFailedConnection: TimeInterval? = nil) {
        self.currentConnectionMode = currentConnectionMode
        self.lastConnectionFailureReason = lastConnectionFailureReason
        self.lastSuccessfulConnection = lastSuccessfulConnection
        self.lastFailedConnection = lastFailedConnection
    }
    
    //Returns ConnectionInformation as a prettyfied string
    public func toString() -> String {
        var connInfoString: String = ""
        connInfoString.append("Current Connection Mode: \(currentConnectionMode.rawValue) | ")
        connInfoString.append("Last Connection Failure Reason: \(lastConnectionFailureReason.getValue()) | ")
        connInfoString.append("Last Successful Connection: \(lastSuccessfulConnection?.stringFromTimeInterval() ?? "NONE") | ")
        connInfoString.append("Last Failed Connection: \(lastFailedConnection?.stringFromTimeInterval() ?? "NONE")")
        return connInfoString
    }
    
    //This function is used to decide what ConnectionMode to set.
    static func connectionModeCheck(config: LDConfig, ldClient: LDClient) -> ConnectionInformation.ConnectionMode {
        let connectionMode: ConnectionInformation.ConnectionMode
        if config.startOnline == false {
            connectionMode = ConnectionInformation.ConnectionMode.offline
        } else if effectiveStreamingMode(config: config, ldClient: ldClient) == LDStreamingMode.streaming {
            connectionMode = ConnectionInformation.ConnectionMode.establishingStreamingConnection
        } else if config.streamingMode == LDStreamingMode.polling {
            connectionMode = ConnectionInformation.ConnectionMode.polling
        } else {
            connectionMode = ConnectionInformation.ConnectionMode.offline
        }
        return connectionMode
    }
    
    //Restores ConnectionInformation from UserDefaults if it exists
    static func uncacheConnectionInformation(config: LDConfig, ldClient: LDClient, clientServiceFactory: ClientServiceCreating) -> ConnectionInformation {
        var connectionInformation = ConnectionInformationStore.retrieveStoredConnectionInformation() ?? clientServiceFactory.makeConnectionInformation()
        connectionInformation.currentConnectionMode = connectionModeCheck(config: config, ldClient: ldClient)
        return connectionInformation
    }
    
    //Used for updating lastSuccessfulConnection when connected to streaming
    static func lastSuccessfulConnectionCheck(flagSynchronizer: LDFlagSynchronizing, connectionInformation: inout ConnectionInformation) -> ConnectionInformation {
        if flagSynchronizer.isOnline && connectionInformation.currentConnectionMode == ConnectionInformation.ConnectionMode.streaming {
            connectionInformation.lastSuccessfulConnection = Date().timeIntervalSince1970
        }
        return connectionInformation
    }
    
    //Used for updating ConnectionInformation inside of LDClient.setOnline
    static func onlineSetCheck(flagSynchronizer: LDFlagSynchronizing, connectionInformation: inout ConnectionInformation, ldClient: LDClient, config: LDConfig) -> ConnectionInformation {
        var connectionInformationVar = ConnectionInformation.lastSuccessfulConnectionCheck(flagSynchronizer: flagSynchronizer, connectionInformation: &connectionInformation)
        
        if ldClient.isOnline && NetworkReporter.isConnectedToNetwork() {
            connectionInformationVar.currentConnectionMode = effectiveStreamingMode(config: config, ldClient: ldClient) == LDStreamingMode.streaming ? ConnectionInformation.ConnectionMode.streaming : ConnectionInformation.ConnectionMode.polling
        } else {
            connectionInformationVar.currentConnectionMode = ConnectionInformation.ConnectionMode.offline
        }
        return connectionInformationVar
    }
    
    //Used for parsing SynchronizingError in LDClient.process
    static func synchronizingErrorCheck(synchronizingError: SynchronizingError, connectionInformation: inout ConnectionInformation) -> ConnectionInformation {
        if synchronizingError.isClientUnauthorized {
            connectionInformation.lastConnectionFailureReason = ConnectionInformation.LastConnectionFailureReason.unauthorized
        } else {
            switch synchronizingError {
            case .request(let error):
                let errorString = error as? String ?? Constants.unknownError
                connectionInformation.lastConnectionFailureReason = ConnectionInformation.LastConnectionFailureReason.unknownError(errorString)
            case .response(let urlResponse):
                let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode
                connectionInformation.lastConnectionFailureReason = ConnectionInformation.LastConnectionFailureReason.httpError(statusCode ?? ConnectionInformation.Constants.noCode)
            default: break
            }
        }
        connectionInformation.lastFailedConnection = Date().timeIntervalSince1970
        return connectionInformation
    }
    
    //Used to create listeners for Connection Status inside the LDClient init
    static func setupListeners(ldClient: LDClient) {
        //Creates a retain cycle that will need to change for multi environment
        ldClient.observeAll(owner: ldClient, handler: { _ in
            Log.debug("LDClient all flags observer fired")
            var connInfo = ldClient.getConnectionInformation()
            ldClient.connectionInformation = ConnectionInformation.checkEstablishingStreaming(connectionInformation: &connInfo)
        })
        ldClient.observeFlagsUnchanged(owner: ldClient, handler: {
            Log.debug("LDClient all flags unchanged observer fired")
            var connInfo = ldClient.getConnectionInformation()
            ldClient.connectionInformation = ConnectionInformation.checkEstablishingStreaming(connectionInformation: &connInfo)
        })
    }
    
    //This function is used to ensure we switch from establishing a streaming connection to streaming once we are connected.
    static func checkEstablishingStreaming(connectionInformation: inout ConnectionInformation) -> ConnectionInformation {
        if connectionInformation.currentConnectionMode == ConnectionInformation.ConnectionMode.establishingStreamingConnection {
            connectionInformation.currentConnectionMode = ConnectionInformation.ConnectionMode.streaming
        }
        connectionInformation.lastSuccessfulConnection = Date().timeIntervalSince1970
        return connectionInformation
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
    
    static func backgroundBehavior(connectionInformation: inout ConnectionInformation, runMode: LDClientRunMode, config: LDConfig, ldClient: LDClient) -> ConnectionInformation {
        if ConnectionInformation.effectiveStreamingMode(config: config, ldClient: ldClient) == LDStreamingMode.streaming && runMode == .background {
            connectionInformation.lastSuccessfulConnection = Date().timeIntervalSince1970
        }
        connectionInformation.currentConnectionMode = .polling
        return connectionInformation
    }
}

extension ConnectionInformation.LastConnectionFailureReason {
    private enum CodingKeys: String, CodingKey {
        case type, payload
    }
    
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .unknownError(let error):
            try container.encode("error", forKey: .type)
            try container.encode(error, forKey: .payload)
        case .httpError(let code):
            try container.encode("code", forKey: .type)
            try container.encode(code, forKey: .payload)
        case .unauthorized, .none:
            break
        }
    }
}

private extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = NSInteger(self)
        let milli = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        
        return String(format: "%0.2d:%0.2d:%0.2d.%0.3d", hours, minutes, seconds, milli)
    }
}
