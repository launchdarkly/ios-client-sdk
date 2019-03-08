//
//  Log.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 3/14/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

protocol Logger {
    func log(_ level: Log.Level, message: String)
}

struct Log {

    enum Level: Int {
        case debug
        case noLogging
    }

    struct BasicLogger: Logger {
        func log(_ level: Level, message: String) {
            var prefix = ""

            switch level {
            case .debug:
                prefix = "LaunchDarkly"
            case .noLogging:
                prefix = ""
            }
            NSLog("%@", "\(prefix): \(message)")
        }
    }

    static var level = Level.noLogging
    static var logger: Logger = BasicLogger()

    static func debug(_ msg: @autoclosure () -> String) {
        if level.rawValue <= Level.debug.rawValue {
            logger.log(.debug, message: msg())
        }
    }
}

protocol TypeIdentifying { }

extension TypeIdentifying {
    var typeName: String {
        return String(describing: type(of: self))
    }
    func typeName(and method: String, appending suffix: String = " ") -> String {
        return typeName + "." + method + suffix
    }
    static var typeName: String {
        return String(describing: self)
    }
    static func typeName(and method: String, appending suffix: String = " ") -> String {
        return typeName + "." + method + suffix
    }
}
