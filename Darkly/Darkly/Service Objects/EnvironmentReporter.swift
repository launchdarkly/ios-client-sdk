//
//  EnvironmentReporter.swift
//  Darkly
//
//  Created by Mark Pokorny on 3/27/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import WatchKit

enum OperatingSystem: String {
    case iOS, watchOS   //TODO: when adding mac & tv support, add cases
}

//sourcery: AutoMockable
protocol EnvironmentReporting {
    //sourcery: DefaultMockValue = true
    var isDebugBuild: Bool { get }
    //sourcery: DefaultMockValue = Constants.deviceModel
    var deviceModel: String { get }
    //sourcery: DefaultMockValue = Constants.systemVersion
    var systemVersion: String { get }
    //sourcery: DefaultMockValue = Constants.systemName
    var systemName: String { get }
    //sourcery: DefaultMockValue = .iOS
    var operatingSystem: OperatingSystem { get }
}

struct EnvironmentReporter: EnvironmentReporting {
    #if DEBUG
    var isDebugBuild: Bool { return true }
    #else
    var isDebugBuild: Bool { return false }
    #endif

    #if os(iOS)
    var deviceModel: String { return UIDevice.current.model }
    var systemVersion: String { return UIDevice.current.systemVersion }
    var systemName: String { return UIDevice.current.systemName }
    var operatingSystem: OperatingSystem { return .iOS }
    #elseif os(watchOS)
    var deviceModel: String { return WKInterfaceDevice.current().model }
    var systemVersion: String { return WKInterfaceDevice.current().systemVersion }
    var systemName: String { return WKInterfaceDevice.current().systemName }
    var operatingSystem: OperatingSystem { return .watchOS }
    //TODO: when adding mac & tv support, add cases
    #endif
}
