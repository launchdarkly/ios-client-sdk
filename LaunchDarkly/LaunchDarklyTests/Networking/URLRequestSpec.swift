//
//  URLRequestSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class URLRequestSpec: XCTestCase {
    func testAppendHeadersNoInitial() {
        var request: URLRequest = URLRequest(url: URL(string: "https://dummy.urlRequest.com")!)
        request.appendHeaders(["headerA": "valueA", "headerB": "valueB"])
        XCTAssertEqual(request.allHTTPHeaderFields, ["headerA": "valueA", "headerB": "valueB"])
    }

    func testAppendHeaders() {
        var request: URLRequest = URLRequest(url: URL(string: "https://dummy.urlRequest.com")!)
        request.allHTTPHeaderFields = ["header1": "value1"]
        request.appendHeaders(["headerA": "valueA"])
        XCTAssertEqual(request.allHTTPHeaderFields, ["header1": "value1", "headerA": "valueA"])
    }

    func testAppendHeadersOverrides() {
        var request: URLRequest = URLRequest(url: URL(string: "https://dummy.urlRequest.com")!)
        request.allHTTPHeaderFields = ["header1": "value1", "header2": "value2"]
        request.appendHeaders(["header1": "value3"])
        XCTAssertEqual(request.allHTTPHeaderFields, ["header1": "value3", "header2": "value2"])
    }
}
