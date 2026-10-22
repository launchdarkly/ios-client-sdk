import Foundation
import OSLog

/// Posts a batch of events to LaunchDarkly once and says what the response means. Android's `AnalyticsEventSender`
/// plays the same part.
///
/// It keeps no state. What an outcome means for the SDK -- the server's time, when to post again, removing the batch --
/// is left to `DirectEventProcessor`, which owns that state.
final class AnalyticsEventSender {
    enum Outcome {
        /// LaunchDarkly took the events. Carries the time the response gave, if it gave one.
        case accepted(serverTime: Date?)
        /// The post failed. The events are kept whatever the failure; it decides only how long to wait.
        case failed(Failure)
    }

    struct Failure {
        let error: SynchronizingError
        /// The response's status, or nil where there was no response.
        let statusCode: Int?
        /// Whether the failure is unlikely to pass soon: a 4xx other than 400, 408 and 429, or a TLS or certificate
        /// failure.
        let unexpected: Bool
        /// The wait the response asked for, or nil where it gave none.
        let retryAfter: TimeInterval?
    }

    private static let tlsErrorCodes: Set<URLError.Code> = [
        .secureConnectionFailed,
        .serverCertificateHasBadDate,
        .serverCertificateUntrusted,
        .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid,
        .clientCertificateRejected,
        .clientCertificateRequired
    ]

    private let service: DarklyServiceProvider

    init(service: DarklyServiceProvider) {
        self.service = service
    }

    /// Posts `body` under `payloadId`. The completion runs once, with the outcome.
    func send(_ body: Data, payloadId: String, eventCount: Int, completion: @escaping (Outcome) -> Void) {
        service.publishEventData(body, payloadId) { response in
            completion(self.outcome(sentEvents: eventCount, response: response.urlResponse as? HTTPURLResponse, error: response.error))
        }
    }

    private func outcome(sentEvents: Int, response: HTTPURLResponse?, error: Error?) -> Outcome {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            os_log("%s Completed sending %d event(s)", log: service.config.logger, type: .debug, typeName(and: #function), sentEvents)
            return .accepted(serverTime: response?.headerDate)
        }

        os_log("%s Sending events failed with error: %s response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error), String(describing: response))
        let statusCode = response?.statusCode
        let unexpected: Bool
        if let statusCode, (400..<600).contains(statusCode) {
            unexpected = HTTPURLResponse.StatusCodes.isTerminalStatusCode(statusCode)
        } else if let urlError = error as? URLError {
            unexpected = AnalyticsEventSender.tlsErrorCodes.contains(urlError.code)
        } else {
            unexpected = false
        }
        return .failed(Failure(error: error.map { .request($0) } ?? .response(response),
                               statusCode: statusCode,
                               unexpected: unexpected,
                               retryAfter: response?.headerRetryAfter))
    }
}

extension AnalyticsEventSender: TypeIdentifying { }
