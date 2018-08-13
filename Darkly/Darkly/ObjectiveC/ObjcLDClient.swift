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
    @objc public var isOnline: Bool { return LDClient.shared.isOnline }
    @objc public var config: ObjcLDConfig { return ObjcLDConfig(LDClient.shared.config) }
    @objc public var user: ObjcLDUser { return ObjcLDUser(LDClient.shared.user) }
    
    // MARK: - Public

    @objc public func setOnline(_ goOnline: Bool, completion:(() -> Void)?) {
        LDClient.shared.setOnline(goOnline, completion: completion)
    }

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

    @objc public func boolVariation(forKey key: LDFlagKey, fallback: Bool) -> Bool {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func integerVariation(forKey key: LDFlagKey, fallback: Int) -> Int {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func doubleVariation(forKey key: LDFlagKey, fallback: Double) -> Double {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func stringVariation(forKey key: LDFlagKey, fallback: String) -> String {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }

    @objc public func arrayVariation(forKey key: LDFlagKey, fallback: [Any]) -> [Any] {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func dictionaryVariation(forKey key: LDFlagKey, fallback: [String: Any]) -> [String: Any] {
        return LDClient.shared.variation(forKey: key, fallback: fallback)
    }
    
    @objc public func boolVariationAndSource(forKey key: LDFlagKey, fallback: Bool) -> ObjcLDBoolVariationValue {
        return ObjcLDBoolVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }

    @objc public func integerVariationAndSource(forKey key: LDFlagKey, fallback: Int) -> ObjcLDIntegerVariationValue {
        return ObjcLDIntegerVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func doubleVariationAndSource(forKey key: LDFlagKey, fallback: Double) -> ObjcLDDoubleVariationValue {
        return ObjcLDDoubleVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func stringVariationAndSource(forKey key: LDFlagKey, fallback: String) -> ObjcLDStringVariationValue {
        return ObjcLDStringVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func arrayVariationAndSource(forKey key: LDFlagKey, fallback: [Any]) -> ObjcLDArrayVariationValue {
        return ObjcLDArrayVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }

    @objc public func dictionaryVariationAndSource(forKey key: LDFlagKey, fallback: [String: Any]) -> ObjcLDDictionaryVariationValue {
        return ObjcLDDictionaryVariationValue(LDClient.shared.variationAndSource(forKey: key, fallback: fallback))
    }
    
    @objc public func observeBool(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDBoolChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDBoolChangedFlag(changedFlag)) }
    }

    @objc public func observeInteger(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDIntegerChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDIntegerChangedFlag(changedFlag)) }
    }
    
    @objc public func observeDouble(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDDoubleChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDDoubleChangedFlag(changedFlag)) }
    }
    
    @objc public func observeString(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDStringChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDStringChangedFlag(changedFlag)) }
    }
    
    @objc public func observeArray(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDArrayChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDArrayChangedFlag(changedFlag)) }
    }
    
    @objc public func observeDictionary(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping (ObjcLDDictionaryChangedFlag) -> Void) {
        LDClient.shared.observe(key: key, owner: owner) { (changedFlag) in handler(ObjcLDDictionaryChangedFlag(changedFlag)) }
    }
    
    @objc public func observeKeys(_ keys: [LDFlagKey], owner: LDFlagChangeOwner, handler: @escaping ([LDFlagKey: ObjcLDChangedFlag]) -> Void) {
        LDClient.shared.observe(keys: keys, owner: owner) { (changedFlags) in
            let objcChangedFlags = changedFlags.mapValues { (changedFlag) -> ObjcLDChangedFlag in changedFlag.objcChangedFlag }
            handler(objcChangedFlags)
        }
    }

    @objc public func observeAllKeys(owner: LDFlagChangeOwner, handler: @escaping ([LDFlagKey: ObjcLDChangedFlag]) -> Void) {
        LDClient.shared.observeAll(owner: owner) { (changedFlags) in
            let objcChangedFlags = changedFlags.mapValues { (changedFlag) -> ObjcLDChangedFlag in changedFlag.objcChangedFlag }
            handler(objcChangedFlags)
        }
    }

    @objc public func observeFlagsUnchanged(owner: LDFlagChangeOwner, handler: @escaping LDFlagsUnchangedHandler) {
        LDClient.shared.observeFlagsUnchanged(owner: owner, handler: handler)
    }
    
    // MARK: - Events

    @objc public func reportEvents() {
        LDClient.shared.reportEvents()
    }

    // MARK: - Private

    private override init() {
        _ = LDClient.shared
    }
}
