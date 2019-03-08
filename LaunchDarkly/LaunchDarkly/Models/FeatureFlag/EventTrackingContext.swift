//
//  EventTrackingContext.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 6/12/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

struct EventTrackingContext {
    enum CodingKeys: String, CodingKey {
        case trackEvents, debugEventsUntilDate
    }

    let trackEvents: Bool
    let debugEventsUntilDate: Date?

    init(trackEvents: Bool, debugEventsUntilDate: Date? = nil) {
        self.trackEvents = trackEvents
        self.debugEventsUntilDate = debugEventsUntilDate
    }

    init?(dictionary: [String: Any]) {
        guard let trackEvents = dictionary.trackEvents
        else {
            return nil
        }
        self.init(trackEvents: trackEvents, debugEventsUntilDate: Date(millisSince1970: dictionary.debugEventsUntilDate))
    }

    init?(object: Any?) {
        guard let dictionary = object as? [String: Any]
        else {
            return nil
        }
        self.init(dictionary: dictionary)
    }

    var dictionaryValue: [String: Any] {
        var contextDictionary: [String: Any] = [CodingKeys.trackEvents.rawValue: trackEvents]
        contextDictionary[CodingKeys.debugEventsUntilDate.rawValue] = debugEventsUntilDate?.millisSince1970
        return contextDictionary
    }

    func shouldCreateDebugEvents(lastEventReportResponseTime: Date?) -> Bool {
        guard let debugEventsUntilDate = debugEventsUntilDate
        else {
            return false
        }
        let comparisonDate = lastEventReportResponseTime ?? Date()
        return comparisonDate.isEarlierThan(debugEventsUntilDate) || comparisonDate == debugEventsUntilDate
    }
}

extension Dictionary where Key == String, Value == Any {
    var trackEvents: Bool? {
        return self[EventTrackingContext.CodingKeys.trackEvents.rawValue] as? Bool
    }
    var debugEventsUntilDate: Int64? {
        return self[EventTrackingContext.CodingKeys.debugEventsUntilDate.rawValue] as? Int64
    }
}
