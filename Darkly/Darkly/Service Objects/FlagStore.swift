//
//  LDFlagStore.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagMaintaining {
    var featureFlags: [LDFlagKey: FeatureFlag] { get }
    //sourcery: DefaultMockValue = .cache
    var flagValueSource: LDFlagValueSource { get }
    func replaceStore(newFlags: [LDFlagKey: Any]?, source: LDFlagValueSource, completion: CompletionClosure?)
    func updateStore(newFlags: [LDFlagKey: Any], source: LDFlagValueSource, completion: CompletionClosure?)
    func deleteFlag(name: LDFlagKey, completion: CompletionClosure?)

    //sourcery: NoMock
    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T
    //sourcery: NoMock
    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource)
}

final class FlagStore: FlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }
    
    private(set) var featureFlags: [LDFlagKey: FeatureFlag] = [:]
    private(set) var flagValueSource = LDFlagValueSource.fallback
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel)

    init() { }

    init(featureFlags: [LDFlagKey: FeatureFlag]?, flagValueSource: LDFlagValueSource = .fallback) {
        self.featureFlags = featureFlags ?? [:]
        self.flagValueSource = flagValueSource
    }

    convenience init(featureFlagDictionary: [LDFlagKey: Any]?, flagValueSource: LDFlagValueSource = .fallback) {
        self.init(featureFlags: featureFlagDictionary?.flagCollection, flagValueSource: flagValueSource)
    }

    ///Replaces all feature flags with new flags. Pass nil to reset to an empty flag store
    func replaceStore(newFlags: [LDFlagKey: Any]?, source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async {
            self.featureFlags = newFlags?.flagCollection ?? [:]
            self.flagValueSource = source
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    ///Not implemented. Implement when patch is implemented in streaming event server
    func updateStore(newFlags: [LDFlagKey: Any], source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    ///Not implemented. Implement when delete is implemented in streaming event server
    func deleteFlag(name: LDFlagKey, completion: CompletionClosure?) {
        flagQueue.async {
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T {
        let (flagValue, _) = variationAndSource(forKey: key, fallback: fallback)
        return flagValue
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource) {
        var (flagValue, source) = (fallback, LDFlagValueSource.fallback)
        if let foundValue = featureFlags[key]?.value as? T {
            //TODO: For collections, it's very easy to pass in a fallback value that the compiler infers to be a type that the developer did not intend. When implementing the logging card, consider splitting up  looking for the key from converting to the type, and logging a detailed message about the expected type requested vs. the type found. The goal is to lead the client app developer to the fact that the fallback was returned because the flag value couldn't be converted to the requested type. For collections it might be that the compiler inferred a different type from the fallback value than the developer intended.
            (flagValue, source) = (foundValue, flagValueSource)
        }
        return (flagValue, source)
    }
}
