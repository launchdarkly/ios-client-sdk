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
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion:(() -> Void)?)
    //sourcery: NoMock
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource)

    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion:(() -> Void)?)
    //sourcery: NoMock
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource)

    func deleteFlag(name: String, completion:(() -> Void)?)
    //sourcery: NoMock
    func deleteFlag(name: String)
}

extension LDFlagMaintaining {
    //sourcery: NoMock
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource) {
        replaceStore(newFlags: newFlags, source: source, completion: nil)
    }

    //sourcery: NoMock
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource) {
        updateStore(newFlags: newFlags, source: source, completion: nil)
    }

    //sourcery: NoMock
    func deleteFlag(name: String) {
        deleteFlag(name: name, completion: nil)
    }
}

final class LDFlagStore: LDFlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }
    
    private(set) var featureFlags: [String: Any] = [:]
    private var flagValueSource = LDFlagValueSource.fallback
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel)

    ///Replaces all feature flags with new flags. Pass nil to reset to an empty flag store
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion:(() -> Void)? = nil) {
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
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion:(() -> Void)?) {
        flagQueue.async {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    ///Not implemented. Implement when delete is implemented in streaming event server
    func deleteFlag(name: String, completion:(() -> Void)?) {
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

    public func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        var source = LDFlagValueSource.fallback
        var flagValue = fallback
        if let foundValue = featureFlags[key] as? T {
            flagValue = foundValue
            source = flagValueSource
        }
        return (flagValue, source)
    }
}
