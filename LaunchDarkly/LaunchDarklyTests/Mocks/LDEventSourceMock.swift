import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly

extension EventHandler {
    func send(event: String, string: String) {
        onMessage(eventType: event, messageEvent: MessageEvent(data: string))
    }

    func sendPing() {
        onMessage(eventType: "ping", messageEvent: MessageEvent(data: ""))
    }

    func sendUnauthorizedError() {
        onError(error: UnsuccessfulResponseError(responseCode: HTTPURLResponse.StatusCodes.unauthorized))
    }

    func sendServerError() {
        onError(error: UnsuccessfulResponseError(responseCode: HTTPURLResponse.StatusCodes.internalServerError))
    }

    func sendNonResponseError() {
        onError(error: DummyError())
    }
}

class EventHandlerMock: EventHandler {
    var onOpenedCallCount = 0
    func onOpened() {
        onOpenedCallCount += 1
    }

    var onClosedCallCount = 0
    func onClosed() {
        onClosedCallCount += 1
    }

    var onMessageCallCount = 0
    var onMessageReceivedArguments: (event: String, messageEvent: MessageEvent)?
    func onMessage(eventType: String, messageEvent: MessageEvent) {
        onMessageCallCount += 1
        onMessageReceivedArguments = (eventType, messageEvent)
    }

    var onCommentCallCount = 0
    var onCommentReceivedComment: String?
    func onComment(comment: String) {
        onCommentCallCount += 1
        onCommentReceivedComment = comment
    }

    var onErrorCallCount = 0
    var onErrorReceivedError: Error?
    func onError(error: Error) {
        onErrorCallCount += 1
        onErrorReceivedError = error
    }
}
