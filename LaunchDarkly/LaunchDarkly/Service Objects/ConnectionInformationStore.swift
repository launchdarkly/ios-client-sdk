//
//  ConnectionInformationStore.swift
//  LaunchDarkly_iOS
//
//  Created by Joe Cieslik on 8/13/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: autoMockable
protocol ConnectionInformationCaching {
    func retrieveStoredConnectionInformation() -> ConnectionInformation?
    func storeConnectionInformation(connectionInformation: ConnectionInformation)
}

final class ConnectionInformationStore: ConnectionInformationCaching {
    fileprivate static let connectionInformationKey = "com.launchDarkly.ConnectionInformationStore.connectionInformationKey"
    
    init() {}
    
    func retrieveStoredConnectionInformation() -> ConnectionInformation? {
        if let storedConnectionInformation = UserDefaults.standard.retrieve(object: ConnectionInformation.self, fromKey: ConnectionInformationStore.connectionInformationKey) {
            return storedConnectionInformation
        }
        return nil
    }
    
    func storeConnectionInformation(connectionInformation: ConnectionInformation) {
        UserDefaults.standard.save(customObject: connectionInformation, forKey: ConnectionInformationStore.connectionInformationKey)
    }
}

extension UserDefaults {
    
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
                Log.debug("Couldnt decode object")
                return nil
            }
        return object
    }
}
