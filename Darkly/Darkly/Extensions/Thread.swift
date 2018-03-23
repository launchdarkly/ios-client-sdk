//
//  Thread.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 3/20/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

extension Thread {
    static func performOnMain(_ executionClosure: () -> Void) {
        guard Thread.isMainThread
        else {
            DispatchQueue.main.sync {
                executionClosure()
            }
            return
        }
        executionClosure()
    }
}
