import Foundation
import OSLog

/// Posts a batch of events to LaunchDarkly, retrying once a second later where the failure may pass, and says what the
/// response means. Android's `AnalyticsEventSender` plays the same part.
///
/// It keeps no state. What an outcome means for the SDK -- the server's time, going offline, removing the batch -- is
/// left to `DirectEventProcessor`, which owns that state.
final class AnalyticsEventSender {
    enum Outcome {
        /// LaunchDarkly took the events. Carries the time the response gave, if it gave one.
        case accepted(serverTime: Date?)
        /// LaunchDarkly will never take these events, so keeping them only wastes space.
        case refused(HTTPURLResponse?)
        /// The events may still be deliverable. Carries why the retry failed.
        case retryable(SynchronizingError)
    }

    private let service: DarklyServiceProvider

    init(service: DarklyServiceProvider) {
        self.service = service
    }

    /// Posts `body` under `payloadId`, and once more after a second if that failed in a way that may pass. The
    /// completion runs once, with the outcome of the last attempt.
    func send(_ body: Data, payloadId: String, eventCount: Int, completion: @escaping (Outcome) -> Void) {
        service.publishEventData(body, payloadId) { response in
            let outcome = self.outcome(sentEvents: eventCount, response: response.urlResponse as? HTTPURLResponse, error: response.error)
            guard case .retryable = outcome
            else {
                completion(outcome)
                return
            }

            os_log("%s Retrying event post after delay.", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                self.service.publishEventData(body, payloadId) { retryResponse in
                    completion(self.outcome(sentEvents: eventCount, response: retryResponse.urlResponse as? HTTPURLResponse, error: retryResponse.error))
                }
            }
        }
    }

    private func outcome(sentEvents: Int, response: HTTPURLResponse?, error: Error?) -> Outcome {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            os_log("%s Completed sending %d event(s)", log: service.config.logger, type: .debug, typeName(and: #function), sentEvents)
            return .accepted(serverTime: response?.headerDate)
        }

        if let statusCode = response?.statusCode, HTTPURLResponse.StatusCodes.isTerminalStatusCode(statusCode) {
            os_log("%s dropping events due to non-retriable response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: response))
            return .refused(response)
        }

        os_log("%s Sending events failed with error: %s response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error), String(describing: response))
        if let error = error {
            return .retryable(.request(error))
        }
        return .retryable(.response(response))
    }
}

extension AnalyticsEventSender: TypeIdentifying { }
