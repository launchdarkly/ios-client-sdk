//
//  LDEventSourceMock.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly

extension EventHandler {
    func send(event: FlagUpdateType, dict: [String: Any]) {
        send(event: event, string: dict.jsonString!)
    }

    func send(event: FlagUpdateType, string: String) {
        onMessage(event: event.rawValue, messageEvent: MessageEvent(data: string))
    }

    func sendPing() {
        onMessage(event: FlagUpdateType.ping.rawValue, messageEvent: MessageEvent(data: ""))
    }

    func sendPut() {
        let data = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)
            .dictionaryValue
        send(event: .put, dict: data)
    }

    func sendPatch() {
        let data = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                           value: DarklyServiceMock.FlagValues.int + 1,
                                                           variation: DarklyServiceMock.Constants.variation + 1,
                                                           version: DarklyServiceMock.Constants.version + 1)
        send(event: .patch, dict: data)
    }

    func sendDelete() {
        let data = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                            version: DarklyServiceMock.Constants.version + 1)
        send(event: .delete, dict: data)
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
    func onMessage(event: String, messageEvent: MessageEvent) {
        onMessageCallCount += 1
        onMessageReceivedArguments = (event, messageEvent)
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
