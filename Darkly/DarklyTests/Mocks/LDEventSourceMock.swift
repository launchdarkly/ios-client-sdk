//
//  LDEventSourceMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/28/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import DarklyEventSource
@testable import Darkly

extension DarklyStreamingProviderMock {
    func sendPing() {
        guard let messageHandler = onMessageEventReceivedHandler else { return }
        messageHandler(DarklyEventSource.LDEvent.stubPingEvent())
    }

    func sendHeartbeat() {
        guard let messageHandler = onMessageEventReceivedHandler else { return }
        messageHandler(DarklyEventSource.LDEvent.stubHeartbeatEvent())
    }

    func sendNullEvent() {
        guard let messageHandler = onMessageEventReceivedHandler else { return }
        messageHandler(nil)
    }

    func sendOpenEvent() {
        guard let messageHandler = onMessageEventReceivedHandler else { return }
        messageHandler(DarklyEventSource.LDEvent.stubOpenEvent())
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

    class func stubOpenEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.id = nil
        event.event = nil
        event.data = nil
        event.readyState = kEventStateOpen
        return event
    }
}
