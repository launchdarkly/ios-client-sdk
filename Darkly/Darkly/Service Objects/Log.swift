//
//  Log.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 3/14/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

protocol Logger {
    func log(_ level: Log.Level, message: String)
}

struct Log {

    /**
     The available levels that can be logged by the Logger.

     - Debug - is good for dumping variable values and runtime details and is typically only turned on for dev builds
     - Warning - is good for logging application problems that aren't fatal or affect users
     - Error - is good for logging application errors that are fatal or impact users
     */
    enum Level: Int {
        case debug
        case warning
        case error
    }

    struct BasicLogger: Logger {
        func log(_ level: Level, message: String) {
            var prefix = ""

            switch level {
            case .debug:
                prefix = "DEBUG"
            case .warning:
                prefix = "WARN"
            case .error:
                prefix = "ERROR"
            }
            NSLog("%@", "\(prefix): \(message)")
        }
    }

    static var level = Level.error
    static var logger: Logger = BasicLogger()

    static func debug(_ msg: @autoclosure () -> String) {
        if level.rawValue <= Level.debug.rawValue {
            logger.log(.debug, message: msg())
        }
    }

    static func warn(_ msg: @autoclosure () -> String) {
        if level.rawValue <= Level.warning.rawValue {
            logger.log(.warning, message: msg())
        }
    }

    static func error(_ msg: @autoclosure () -> String) {
        if level.rawValue <= Level.error.rawValue {
            logger.log(.error, message: msg())
        }
    }
}

protocol TypeIdentifying { }

extension TypeIdentifying {
    var typeName: String { return String(describing: type(of: self)) }
    func typeName(and method: String, appending suffix: String = " ") -> String {
        return typeName + "." + method + suffix
    }
    static var typeName: String { return String(describing: self) }
    static func typeName(and method: String, appending suffix: String = " ") -> String {
        return typeName + "." + method + suffix
    }
}
