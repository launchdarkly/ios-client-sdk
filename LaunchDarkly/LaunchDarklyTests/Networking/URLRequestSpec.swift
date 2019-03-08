//
//  URLRequestSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 9/28/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class URLRequestSpec: QuickSpec {

    struct Constants {
        static let dummyUrl = URL(string: "https://dummy.urlRequest.com")!
        static let startingHeaders = ["header1": "value1", "header2": "value2", "header3": "value3"]
        static let newHeaders = ["headerA": "valueA", "headerB": "valueB"]
    }

    var subject: URLRequest!

    override func spec() {

        describe("appendHeaders") {
            context("no new headers exist in original") {
                var targetHeaders = Constants.startingHeaders
                beforeEach {
                    Constants.newHeaders.forEach { (key, value) in
                        targetHeaders[key] = value
                    }

                    self.subject = URLRequest(url: Constants.dummyUrl)
                    self.subject.allHTTPHeaderFields = Constants.startingHeaders
                    expect(self.subject.allHTTPHeaderFields) == Constants.startingHeaders

                    self.subject.appendHeaders(Constants.newHeaders)
                }
                it("adds new headers") {
                    expect(self.subject.allHTTPHeaderFields) == targetHeaders
                }
            }
            context("some new headers exist in original") {
                var targetHeaders = Constants.startingHeaders
                beforeEach {
                    var startingHeaders = Constants.startingHeaders
                    startingHeaders["headerA"] = "wrongValue"

                    targetHeaders = startingHeaders
                    Constants.newHeaders.forEach { (key, value) in
                        targetHeaders[key] = value
                    }

                    self.subject = URLRequest(url: Constants.dummyUrl)
                    self.subject.allHTTPHeaderFields = startingHeaders
                    expect(self.subject.allHTTPHeaderFields) == startingHeaders

                    self.subject.appendHeaders(Constants.newHeaders)
                }
                it("adds new headers") {
                    expect(self.subject.allHTTPHeaderFields) == targetHeaders
                }
            }
        }
    }
}
