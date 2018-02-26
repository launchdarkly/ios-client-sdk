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
        sendEvent(DarklyEventSource.LDEvent.stubPingEvent())
    }

    func sendHeartbeat() {
        sendEvent(DarklyEventSource.LDEvent.stubHeartbeatEvent())
    }

    func sendNullEvent() {
        sendEvent(nil)
    }

    func sendOpenEvent() {
        sendEvent(DarklyEventSource.LDEvent.stubOpenEvent())
    }

    func sendPut() {
        sendEvent(DarklyEventSource.LDEvent.stubPutEvent())
    }

    func sendPatch() {
        sendEvent(DarklyEventSource.LDEvent.stubPatchEvent())
    }

    func sendDelete() {
        sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent())
    }

    func sendEvent(_ event: DarklyEventSource.LDEvent?) {
        guard let messageHandler = onMessageEventReceivedHandler else { return }
        messageHandler(event)
    }
}

extension DarklyEventSource.LDEvent {
    class func stubPingEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.ping.rawValue
        event.data = ""
        event.readyState = kEventStateOpen
        return event
    }
    
    class func stubHeartbeatEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.heartbeat.rawValue
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

    class func stubPutEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.put.rawValue
        event.data = DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false).jsonString!
        event.readyState = kEventStateOpen
        return event
    }

    class func stubPatchEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.patch.rawValue
        event.data = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int, value: DarklyServiceMock.FlagValues.int + 1, version: DarklyServiceMock.Constants.version + 1).jsonString!
        event.readyState = kEventStateOpen
        return event
    }

    class func stubDeleteEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.delete.rawValue
        event.data = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1).jsonString!
        event.readyState = kEventStateOpen
        return event
    }

}
