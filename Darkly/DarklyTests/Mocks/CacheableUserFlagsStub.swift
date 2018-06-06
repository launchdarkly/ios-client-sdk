//
//  CacheableUserFlagsStub.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 2/21/18.
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension CacheableUserFlags {
    static func stub() -> CacheableUserFlags {
        return CacheableUserFlags(flags: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true),
                                  lastUpdated: Date())
    }
}
