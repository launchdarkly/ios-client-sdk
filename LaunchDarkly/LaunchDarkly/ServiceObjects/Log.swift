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
        String(describing: type(of: self))
    }

    func typeName(and method: String, appending suffix: String = " ") -> String {
        typeName + "." + method + suffix
    }

    static var typeName: String {
        String(describing: self)
    }

    static func typeName(and method: String, appending suffix: String = " ") -> String {
        typeName + "." + method + suffix
    }
}
