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

/**
 When a new `LDContext` is being identified, the SDK has a few choices it can make on how to handle intermediate flag evaluations
 until fresh values have been retrieved from the LaunchDarkly APIs.
 */
public enum IdentifyCacheUsage {
    /**
     `no` will not load any flag values from the cache. Instead it will maintain the current in memory state from the previously identified context.

     This method ensures the greatest continuity of experience until the identify network communication resolves.
     */
    case no

    /**
     `yes` will clear the in memory state of any previously known flag values. The SDK will attempt to load cached flag values for the newly identified
     context. If no cache is found, the state remains empty until the network request resolves.
     */
    case yes

    /**
     `ifAvailable` will attempt to load cached flag values for the newly identified context. If cached values are found, the in memory state is fully
     replaced with those values.

     If no cached values are found, the existing in memory state is retained until the network request resolves.
     */
    case ifAvailable
}
