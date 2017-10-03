//
//  LDEventSourceMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/28/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import DarklyEventSource
@testable import Darkly

final class LDEventSourceMock: DarklyStreamingProvider {
    var onMessageCallCount = 0
    var onMessageHandler: LDEventSourceEventHandler?
    func onMessageEvent(_ handler: LDEventSourceEventHandler?) {
        onMessageCallCount += 1
        onMessageHandler = handler
    }

    func sendPing() {
        guard let messageHandler = onMessageHandler else { return }
        messageHandler(DarklyEventSource.LDEvent.stubPingEvent())
    }

    func sendHeartbeat() {
        guard let messageHandler = onMessageHandler else { return }
        messageHandler(DarklyEventSource.LDEvent.stubHeartbeatEvent())
    }

    func sendNullEvent() {
        guard let messageHandler = onMessageHandler else { return }
        messageHandler(nil)
    }

    var closeCallCount = 0
    func close() {
        closeCallCount += 1
    }
}

extension DarklyEventSource.LDEvent {
    class func stubPingEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = "ping"
        event.data = ""
        event.readyState = kEventStateOpen
        return event
    }
    class func stubHeartbeatEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = ":"
        event.data = ""
        event.readyState = kEventStateOpen
        return event
    }
}
