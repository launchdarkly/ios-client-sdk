//
//  LDFlagStore.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

protocol LDFlagMaintaining {
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource)
    func replaceStore(newFlags: [String: Any], source: LDFlagValueSource)
    func deleteFlag(name: String)
}

final class LDFlagStore: LDFlagMaintaining {

    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }
    
    private var featureFlags: [String: LDFeatureFlag]
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel)
    var user: LDUser
    
    init() {
        featureFlags = [:]
        user = LDUser()
    }
    
    init(user: LDUser) {
        featureFlags = [:]
        self.user = user
    }
    
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource) {
        flagQueue.async {

        }
    }
    
    func replaceStore(newFlags: [String: Any], source: LDFlagValueSource) {
        flagQueue.async {

        }
    }
    
    func deleteFlag(name: String) {
        flagQueue.async {
            
        }
    }
}
