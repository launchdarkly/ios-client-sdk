//
//  LDFlagStore.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol LDFlagMaintaining {
    var featureFlags: [String: Any] { get }
    //sourcery: DefaultMockValue = .cache
    var flagValueSource: LDFlagValueSource { get }
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion: CompletionClosure?)
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?)
    func deleteFlag(name: String, completion: CompletionClosure?)

    //sourcery: NoMock
    func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T
    //sourcery: NoMock
    func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource)
}

final class LDFlagStore: LDFlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }
    
    private(set) var featureFlags: [String: Any] = [:]
    private(set) var flagValueSource = LDFlagValueSource.fallback
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel)

    init() { }

    init(featureFlags: [String: Any]?, flagValueSource: LDFlagValueSource = .fallback) {
        self.featureFlags = featureFlags ?? [:]
        self.flagValueSource = flagValueSource
    }

    ///Replaces all feature flags with new flags. Pass nil to reset to an empty flag store
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async {
            self.featureFlags = newFlags ?? [:]
            self.flagValueSource = source
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    ///Not implemented. Implement when patch is implemented in streaming event server
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    ///Not implemented. Implement when delete is implemented in streaming event server
    func deleteFlag(name: String, completion: CompletionClosure?) {
        flagQueue.async {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T {
        let (flagValue, _) = variationAndSource(forKey: key, fallback: fallback)
        return flagValue
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        var source = LDFlagValueSource.fallback
        var flagValue = fallback
        if let foundValue = featureFlags[key] as? T {
            flagValue = foundValue
            source = flagValueSource
        }
        return (flagValue, source)
    }
}
