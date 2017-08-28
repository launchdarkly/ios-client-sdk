//
//  LDEventReporter.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

class LDEventReporter {
    fileprivate struct Constants {
        static let eventQueueLabel = "com.launchdarkly.eventSyncQueue"
    }
    
    private let config: LDConfig
    private let eventQueue = DispatchQueue(label: Constants.eventQueueLabel, qos: .userInitiated)
    var isOnline: Bool {
        didSet {
            
        }
    }

    private var eventStore = [LDEvent]()

    init(config: LDConfig) {
        self.config = config
        
        self.isOnline = config.launchOnline
    }

    private func startSyncing() {
        
    }
    
    private func stopSyncing() {
        
    }
    
    private func syncEvents() {
        
    }
}
