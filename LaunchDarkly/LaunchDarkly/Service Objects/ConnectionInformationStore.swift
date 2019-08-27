//
//  ConnectionInformationStore.swift
//  LaunchDarkly_iOS
//
//  Created by Joe Cieslik on 8/13/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

final class ConnectionInformationStore {
    private static let connectionInformationKey = "com.launchDarkly.ConnectionInformationStore.connectionInformationKey"
    
    static func retrieveStoredConnectionInformation() -> ConnectionInformation? {
        return UserDefaults.standard.retrieve(object: ConnectionInformation.self, fromKey: ConnectionInformationStore.connectionInformationKey)
    }
    
    static func storeConnectionInformation(connectionInformation: ConnectionInformation) {
        UserDefaults.standard.save(customObject: connectionInformation, forKey: ConnectionInformationStore.connectionInformationKey)
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
            else {
                Log.debug("Couldnt decode object: \(key)")
                return nil
            }
        return object
    }
}
