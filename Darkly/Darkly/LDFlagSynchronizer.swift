//
//  LDFlagSynchronizer.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import Dispatch

//Responsible for SSE / Polling setup and server flag request & handling
class LDFlagSynchronizer {
    struct Constants {
        static let requestQueueLabel = "com.launchdarkly.flagRequestQueue"
    }
    
    let config: LDConfig
    let user: LDUser
    let requestQueue = DispatchQueue(label: Constants.requestQueueLabel, qos: .userInitiated)
    var streamingMode: LDStreamingMode {
        didSet {
            
        }
    }
    
    var isOnline: Bool {
        didSet {
            
        }
    }
    
    init(config: LDConfig, user: LDUser) {
        self.config = config
        self.user = user
        
        self.isOnline = config.launchOnline
        self.streamingMode = config.streamingMode
    }
    
    private func startEventSource() {
    
    }
    
    private func stopEventSource() {
        
    }
    
    private func startPolling() {
        
    }
    
    private func stopPolling() {
        
    }
    
    private func makeFlagRequest() {
        
    }
}
