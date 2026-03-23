import Foundation

final class ConnectionInformationStore {
    private static let connectionInformationKey = "com.launchDarkly.ConnectionInformationStore.connectionInformationKey"
    private static let storeQueue = DispatchQueue(label: "com.launchDarkly.ConnectionInformationStore.storeQueue")

    static func retrieveStoredConnectionInformation() -> ConnectionInformation? {
        UserDefaults.standard.retrieve(object: ConnectionInformation.self, fromKey: connectionInformationKey)
    }

    static func storeConnectionInformation(connectionInformation: ConnectionInformation) {
        storeQueue.async {
            UserDefaults.standard.save(customObject: connectionInformation, forKey: connectionInformationKey)
        }
    }
}

private extension UserDefaults {
    func save<T: Encodable>(customObject object: T, forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(object) {
            self.set(encoded, forKey: key)
        }
    }

    func retrieve<T: Decodable>(object type: T.Type, fromKey key: String) -> T? {
        guard let data = self.data(forKey: key),
            let object = try? JSONDecoder().decode(type, from: data)
        else { return nil }

        return object
    }
}
