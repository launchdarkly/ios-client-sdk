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
        messageHandler(LDEvent.stubPingEvent())
    }

    func sendHeartbeat() {
        guard let messageHandler = onMessageHandler else { return }
        messageHandler(LDEvent.stubHeartbeatEvent())
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

extension LDEvent {
    class func stubPingEvent() -> LDEvent {
        let event = LDEvent()
        event.event = "ping"
        event.data = ""
        event.readyState = kEventStateOpen
        return event
    }
    class func stubHeartbeatEvent() -> LDEvent {
        let event = LDEvent()
        event.event = ":"
        event.data = ""
        event.readyState = kEventStateOpen
        return event
    }
}
