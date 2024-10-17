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
public enum IdentifyCacheHandling {
    /**
     `keep` will maintain the current in memory store of any previously known flag values from the last identified context.

     This method will ensure the greatest continuity of experience while the identify network communication resolves.
     */
    case keep

    /**
     `keepOnMiss` will only maintain the current in memory store if there are no previously cached values for the new `LDContext`.
     If cached values exist, the memory store will be replaced with those values.
     */
    case keepOnMiss

    /**
     `discard` will clear the in memory store of any previously known flag values from the last identified context.

     The SDK will load any previously cached values for this context, or load an empty memory store on a cache miss.
     */
    case discard
}
