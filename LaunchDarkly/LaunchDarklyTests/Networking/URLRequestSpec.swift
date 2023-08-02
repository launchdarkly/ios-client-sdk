import Foundation
import XCTest

@testable import LaunchDarkly

final class URLRequestSpec: XCTestCase {
    func testInitExtension() {
        var delegateArgs: (url: URL, headers: [String: String])?

        let url = URL(string: "https://dummy.urlRequest.com")!
        var config = LDConfig(mobileKey: "testkey", autoEnvAttributes: .disabled)
        config.connectionTimeout = 15
        config.headerDelegate = { url, headers in
            delegateArgs = (url, headers)
            return ["Proxy": "Other"]
        }
        let request: URLRequest = URLRequest(url: url,
                                             ldHeaders: ["Authorization": "api_key foo"],
                                             ldConfig: config)

        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(delegateArgs?.url, url)
        XCTAssertEqual(delegateArgs?.headers, ["Authorization": "api_key foo"])
        XCTAssertEqual(request.allHTTPHeaderFields, ["Proxy": "Other"])
    }
}
