import Foundation
import XCTest

@testable import LaunchDarkly

final class HTTPHeadersSpec: XCTestCase {

    func testFlagRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.flagRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(SystemCapabilities.systemName)/\(ReportingConsts.sdkVersion)")
        XCTAssertNil(headers[HTTPHeaders.HeaderKey.ifNoneMatch])
    }

    func testEventSourceDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.eventSourceHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(SystemCapabilities.systemName)/\(ReportingConsts.sdkVersion)")
    }

    func testEventRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.eventRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(SystemCapabilities.systemName)/\(ReportingConsts.sdkVersion)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.contentType], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.accept], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.eventSchema], HTTPHeaders.HeaderValue.eventSchema4)
    }

    func testDiagnosticRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.diagnosticRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(SystemCapabilities.systemName)/\(ReportingConsts.sdkVersion)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.contentType], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.accept], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertNil(headers[HTTPHeaders.HeaderKey.eventSchema])
    }

    func testWrapperNameIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperName = "test-wrapper"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["X-LaunchDarkly-Wrapper"], "test-wrapper")
        }
    }

    func testOnlyWrapperVersionNotIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperVersion = "0.1.0"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertNil(headers["X-LaunchDarkly-Wrapper"])
        }
    }

    func testWrapperNameAndVersionIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperName = "test-wrapper"
        config.wrapperVersion = "0.1.0"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["X-LaunchDarkly-Wrapper"], "test-wrapper/0.1.0")
        }
    }

    func testApplicationInfoTagIsGeneratedCorrectly() {
        let config = LDConfig.stub
        var appInfo = ApplicationInfo()

        appInfo.applicationIdentifier("example-id")
        appInfo.applicationName("example-name")
        appInfo.applicationVersion("example-version")
        appInfo.applicationVersionName("example-version-name")

        let environmentReporter = EnvironmentReportingMock()
        environmentReporter.applicationInfo = appInfo

        let httpHeaders = HTTPHeaders(config: config, environmentReporter: environmentReporter)

        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["X-LaunchDarkly-Tags"], Optional("application-id/example-id application-name/example-name application-version/example-version application-version-name/example-version-name"))
        }
    }
}
