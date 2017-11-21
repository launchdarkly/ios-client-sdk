//
//  LDClientWrapper.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/7/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc(LDClient)
public final class ObjcLDClient: NSObject {
    @objc public static let sharedInstance = ObjcLDClient()
    @objc public var isOnline: Bool {
        get { return LDClient.shared.isOnline }
        set { LDClient.shared.isOnline = newValue }
    }
    @objc public var config: ObjcLDConfig { return ObjcLDConfig(LDClient.shared.config) }
    @objc public var user: ObjcLDUser { return ObjcLDUser(LDClient.shared.user) }
    
    // MARK: - Public
    
    @objc public func startWithMobileKey(_ mobileKey: String, config: ObjcLDConfig? = nil, user userObject: ObjcLDUser? = nil) {
        if let configObject = config {
            LDClient.shared.start(mobileKey: mobileKey, config: configObject.config, user: userObject?.user)
            return
        }
        LDClient.shared.start(mobileKey: mobileKey, user: userObject?.user)
    }
    
    @objc(setConfig:) public func setConfig(_ config: ObjcLDConfig) {
        LDClient.shared.config = config.config
    }
    
    @objc(setUser:) public func setUser(_ user: ObjcLDUser) {
        LDClient.shared.user = user.user
    }

    @objc public func stop() {
        LDClient.shared.stop()
    }

    @objc public func trackEvent(key: String, data: [String: Any]? = nil) {
        LDClient.shared.trackEvent(key: key, data: data)
    }
    
    // MARK: Feature Flag values

    @objc public func boolVariation(forKey key: String, fallback: Bool) -> Bool {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func integerVariation(forKey key: String, fallback: Int) -> Int {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func doubleVariation(forKey key: String, fallback: Double) -> Double {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func stringVariation(forKey key: String, fallback: String) -> String {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func arrayVariation(forKey key: String, fallback: [Any]) -> [Any] {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func dictionaryVariation(forKey key: String, fallback: [String: Any]) -> [String: Any] {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func boolVariationAndSource(forKey key: String, fallback: Bool) -> ObjcLDBoolVariationValue {
        return ObjcLDBoolVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }

    @objc public func integerVariationAndSource(forKey key: String, fallback: Int) -> ObjcLDIntegerVariationValue {
        return ObjcLDIntegerVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func doubleVariationAndSource(forKey key: String, fallback: Double) -> ObjcLDDoubleVariationValue {
        return ObjcLDDoubleVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func stringVariationAndSource(forKey key: String, fallback: String) -> ObjcLDStringVariationValue {
        return ObjcLDStringVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func arrayVariationAndSource(forKey key: String, fallback: [Any]) -> ObjcLDArrayVariationValue {
        return ObjcLDArrayVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }

    @objc public func dictionaryVariationAndSource(forKey key: String, fallback: [String: Any]) -> ObjcLDDictionaryVariationValue {
        return ObjcLDDictionaryVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func observeBool(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDBoolChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDBoolChangedFlag(changedFlag)) }
    }

    @objc public func observeInteger(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDIntegerChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDIntegerChangedFlag(changedFlag)) }
    }
    
    @objc public func observeDouble(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDDoubleChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDDoubleChangedFlag(changedFlag)) }
    }
    
    @objc public func observeString(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDStringChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDStringChangedFlag(changedFlag)) }
    }
    
    @objc public func observeArray(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDArrayChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDArrayChangedFlag(changedFlag)) }
    }
    
    @objc public func observeDictionary(_ key: String, owner: LDFlagChangeOwner, observer: @escaping (ObjcLDDictionaryChangedFlag) -> Void) {
        LDClient.shared.observe(key, owner: owner) { (changedFlag) in observer(ObjcLDDictionaryChangedFlag(changedFlag)) }
    }
    
    @objc public func observeAllKeys(owner: LDFlagChangeOwner, observer: @escaping ([String: ObjcLDChangedFlag]) -> Void) {
        LDClient.shared.observeAll(owner: owner) { (changedFlags) in
            let objcChangedFlags = changedFlags.mapValues { (changedFlag) -> ObjcLDChangedFlag in changedFlag.objcChangedFlag }
            observer(objcChangedFlags)
        }
    }
    
    private override init() {
        _ = LDClient.shared
    }
}
