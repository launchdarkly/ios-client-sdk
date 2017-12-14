//
//  ClientServiceFactory.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

protocol ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching
    func makeCacheConverter() -> UserCacheConverting
    func makeCacheConverter(keyStore: KeyedValueCaching) -> UserCacheConverting
    func makeFlagCollectionCache(keyStore: KeyedValueCaching) -> FlagCollectionCaching
    func makeUserFlagCache() -> UserFlagCaching
    func makeUserFlagCache(flagCollectionStore: FlagCollectionCaching) -> UserFlagCaching
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining, onSync: FlagsReceivedClosure?) -> LDFlagSynchronizing
    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting
}

struct ClientServiceFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        return UserDefaults.standard
    }

    func makeCacheConverter() -> UserCacheConverting {
        return makeCacheConverter(keyStore: makeKeyedValueCache())
    }

    func makeCacheConverter(keyStore: KeyedValueCaching) -> UserCacheConverting {
        return UserCacheConverter(keyStore: keyStore, flagCollectionCache: makeFlagCollectionCache(keyStore: keyStore))
    }

    func makeFlagCollectionCache(keyStore: KeyedValueCaching) -> FlagCollectionCaching {
        return FlagCollectionCache(keyStore: keyStore)
    }

    func makeUserFlagCache() -> UserFlagCaching {
        return UserFlagCache(flagCollectionStore: makeFlagCollectionCache(keyStore: makeKeyedValueCache()))
    }

    func makeUserFlagCache(flagCollectionStore: FlagCollectionCaching) -> UserFlagCaching {
        return UserFlagCache(flagCollectionStore: flagCollectionStore)
    }

    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyService(mobileKey: mobileKey, config: config, user: user)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining, onSync: FlagsReceivedClosure?) -> LDFlagSynchronizing {
        return LDFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, service: service, store: store, onSync: onSync)
    }

    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting {
        return LDEventReporter(mobileKey: mobileKey, config: config, service: service)
    }
}
