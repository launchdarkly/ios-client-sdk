import Foundation

/**
 Denotes the result of an identify request made through the `LDClient.identify(context: completion:)` method.
 */
public enum IdentifyResult {
    /**
     The identify request has completed successfully.
     */
    case complete
    /**
     The identify request has received an unrecoverable failure.
     */
    case error
    /**
     The identify request has been replaced with a subsequent request. Read `LDClient.identify(context: completion:)` for more details.
     */
    case shed
    /**
     The identify request exceeded some time out parameter. Read `LDClient.identify(context: timeout: completion)` for more details.
     */
    case timeout

    init(from: TaskResult) {
        switch from {
        case .complete:
            self = .complete
        case .error:
            self = .error
        case .shed:
            self = .shed
        }
    }
}
