//
//  CacheableUserFlagsStub.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/21/18.
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension CacheableUserFlags {
    static func stub() -> CacheableUserFlags {
        return CacheableUserFlags(userKey: UUID().uuidString, flags: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false), lastUpdated: Date())
    }
}
