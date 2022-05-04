import Foundation

// sourcery: autoMockable
protocol KeyedValueCaching {
    func set(_ value: Data, forKey: String)
    func data(forKey: String) -> Data?
    func dictionary(forKey: String) -> [String: Any]?
    func removeObject(forKey: String)
    func removeAll()
}

extension UserDefaults: KeyedValueCaching {
    func set(_ value: Data, forKey: String) {
        set(value as Any?, forKey: forKey)
    }

    func removeAll() {
        dictionaryRepresentation().keys.forEach { removeObject(forKey: $0) }
    }
}
