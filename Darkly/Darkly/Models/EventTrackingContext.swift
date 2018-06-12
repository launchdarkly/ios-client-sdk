//
//  EventTrackingContext.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct EventTrackingContext {
    enum CodingKeys: String, CodingKey {
        case trackEvents
    }

    let trackEvents: Bool

    init(trackEvents: Bool) {
        self.trackEvents = trackEvents
    }

    init?(dictionary: [String: Any]) {
        guard let trackEvents = dictionary.trackEvents else { return nil }
        self.init(trackEvents: trackEvents)
    }

    init?(object: Any?) {
        guard let dictionary = object as? [String: Any] else { return nil }
        self.init(dictionary: dictionary)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.trackEvents.rawValue: trackEvents]
    }
}

extension Dictionary where Key == String, Value == Any {
    var trackEvents: Bool? {
        return self[EventTrackingContext.CodingKeys.trackEvents.rawValue] as? Bool
    }
}
