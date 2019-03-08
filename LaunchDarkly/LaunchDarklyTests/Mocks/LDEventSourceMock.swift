//
//  LDEventSourceMock.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 9/28/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import DarklyEventSource
@testable import LaunchDarkly

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

    func sendPut() {
        sendEvent(DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)
            .dictionaryValue
            .jsonString))
    }

    func sendPatch() {
        sendEvent(DarklyEventSource.LDEvent.stubPatchEvent(data: FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                                         value: DarklyServiceMock.FlagValues.int + 1,
                                                                                                         variation: DarklyServiceMock.Constants.variation + 1,
                                                                                                         version: DarklyServiceMock.Constants.version + 1).jsonString))
    }

    func sendDelete() {
        sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent(data: FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                                           version: DarklyServiceMock.Constants.version + 1).jsonString))
    }

    func sendEvent(_ event: DarklyEventSource.LDEvent?) {
        guard let messageHandler = onMessageEventReceivedHandler
        else {
            return
        }
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

    class func stubPutEvent(data: String?) -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.put.rawValue
        event.data = data
        event.readyState = kEventStateOpen
        return event
    }

    class func stubPatchEvent(data: String?) -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.patch.rawValue
        event.data = data
        event.readyState = kEventStateOpen
        return event
    }

    class func stubDeleteEvent(data: String?) -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.event = EventType.delete.rawValue
        event.data = data
        event.readyState = kEventStateOpen
        return event
    }

    class func stubUnauthorizedEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.error = NSError(domain: DarklyEventSource.LDEventSourceErrorDomain, code: -HTTPURLResponse.StatusCodes.unauthorized, userInfo: nil)
        event.readyState = kEventStateClosed
        return event
    }

    class func stubErrorEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.error = NSError(domain: "", code: HTTPURLResponse.StatusCodes.internalServerError, userInfo: nil)
        event.readyState = kEventStateClosed
        return event
    }

    class func stubNonNSErrorEvent() -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.error = DummyError()
        event.readyState = kEventStateClosed
        return event
    }

    class func stubReadyStateEvent(eventState: DarklyEventSource.LDEventState) -> DarklyEventSource.LDEvent {
        let event = DarklyEventSource.LDEvent()
        event.readyState = eventState
        return event
    }
}
