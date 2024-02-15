import Foundation

protocol TypeIdentifying { }

extension TypeIdentifying {
    var typeName: String {
        String(describing: type(of: self))
    }

    func typeName(and method: String) -> String {
        typeName + "." + method
    }

    static var typeName: String {
        String(describing: self)
    }

    static func typeName(and method: String) -> String {
        typeName + "." + method
    }
}
