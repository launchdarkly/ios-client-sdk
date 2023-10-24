import Foundation
import XCTest

@testable import LaunchDarkly

final class ModifierSpec: XCTestCase {
    /**
     * Requirement 1.2.2.1 - Schema adherence
     * Requirement 1.2.2.3 - Adding all attributes
     * Requirement 1.2.2.5 - Schema version in envAttributes
     * Requirement 1.2.2.7 - Adding all context kinds
     */
    func testAdheresToSchema() throws {
        let underTest = AutoEnvContextModifier(environmentReporter: EnvironmentReportingMock())

        var inputBuilder = LDContextBuilder(key: "aKey")
        inputBuilder.kind("aKind")
        inputBuilder.trySetValue("dontOverwriteMeBro", "really bro")
        let input = try inputBuilder.build().get()

        let outputContext = underTest.modifyContext(input)

        // pull the generated keys out and set them on contexts, this is so
        // we can use the built in context equality check in our assertions
        var appBuilder = LDContextBuilder(key: outputContext.contextKeys()["ld_application"]!)
        appBuilder.kind("ld_application")
        appBuilder.trySetValue("id", LDValue.string(EnvironmentReportingMock.Constants.applicationInfo.applicationId!))
        appBuilder.trySetValue("version", LDValue.string(EnvironmentReportingMock.Constants.applicationInfo.applicationVersion!))
        appBuilder.trySetValue("name", LDValue.string(EnvironmentReportingMock.Constants.applicationInfo.applicationName!))
        appBuilder.trySetValue("versionName", LDValue.string(EnvironmentReportingMock.Constants.applicationInfo.applicationVersionName!))
        appBuilder.trySetValue("locale", LDValue.string(EnvironmentReportingMock.Constants.locale))
        appBuilder.trySetValue("envAttributesVersion", AutoEnvContextModifier.specVersion.toLDValue())
        let appContext = try appBuilder.build().get()

        var deviceBuilder = LDContextBuilder(key: outputContext.contextKeys()["ld_device"]!)
        deviceBuilder.kind("ld_device")
        deviceBuilder.trySetValue("manufacturer", LDValue.string(EnvironmentReportingMock.Constants.manufacturer))
        deviceBuilder.trySetValue("model", LDValue.string(EnvironmentReportingMock.Constants.deviceModel))
        deviceBuilder.trySetValue("os", LDValue(dictionaryLiteral:
            ("family", EnvironmentReportingMock.Constants.osFamily.toLDValue()),
            ("name", SystemCapabilities.systemName.toLDValue()),
            ("version", EnvironmentReportingMock.Constants.systemVersion.toLDValue())
        ))
        deviceBuilder.trySetValue("envAttributesVersion", AutoEnvContextModifier.specVersion.toLDValue())
        let deviceContext = try deviceBuilder.build().get()

        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(input)
        multiBuilder.addContext(appContext)
        multiBuilder.addContext(deviceContext)
        let expectedContext = try multiBuilder.build().get()

        // Ensure we didn't remove them from the existing context.
        XCTAssertEqual(3, outputContext.contextKeys().count)
        XCTAssertTrue(outputContext.isMulti())
        XCTAssertEqual(expectedContext, outputContext)
    }

    /**
     *  Requirement 1.2.2.6 - Don't add kind if already exists
     *  Requirement 1.2.5.1 - Doesn't change customer provided data
     *  Requirement 1.2.7.1 - Log warning when kind already exists
     */
    func testDoesNotOverwriteCustomerData() throws {
        let underTest = AutoEnvContextModifier(environmentReporter: EnvironmentReportingMock())

        var inputBuilder = LDContextBuilder(key: "aKey")
        inputBuilder.kind("ld_application")
        inputBuilder.trySetValue("dontOverwriteMeBro", "really bro")
        let input = try inputBuilder.build().get()

        let outputContext = underTest.modifyContext(input)

        var deviceBuilder = LDContextBuilder(key: outputContext.contextKeys()["ld_device"]!)
        deviceBuilder.kind("ld_device")
        deviceBuilder.trySetValue("manufacturer", EnvironmentReportingMock.Constants.manufacturer.toLDValue())
        deviceBuilder.trySetValue("model", EnvironmentReportingMock.Constants.deviceModel.toLDValue())
        deviceBuilder.trySetValue("os", LDValue(dictionaryLiteral:
            ("family", EnvironmentReportingMock.Constants.osFamily.toLDValue()),
            ("name", SystemCapabilities.systemName.toLDValue()),
            ("version", EnvironmentReportingMock.Constants.systemVersion.toLDValue())
        ))
        deviceBuilder.trySetValue("envAttributesVersion", AutoEnvContextModifier.specVersion.toLDValue())
        let deviceContext = try deviceBuilder.build().get()

        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(input)
        multiBuilder.addContext(deviceContext)
        let expectedContext = try multiBuilder.build().get()

        // Ensure we didn't remove them from the existing context.
        XCTAssertEqual(2, outputContext.contextKeys().count)
        XCTAssertTrue(outputContext.isMulti())
        XCTAssertEqual(expectedContext, outputContext)
    }

    /**
     *  Requirement 1.2.5.1 - Doesn't change customer provided data
     */
    func testDoesNotOverwriteCustomerDataMultiContext() throws {
        let underTest = AutoEnvContextModifier(environmentReporter: EnvironmentReportingMock())

        var inputBuilder1 = LDContextBuilder(key: "aKey")
        inputBuilder1.kind("ld_application")
        inputBuilder1.trySetValue("dontOverwriteMeBro", "really bro")
        let input1 = try inputBuilder1.build().get()

        var inputBuilder2 = LDContextBuilder(key: "aKey")
        inputBuilder2.kind("ld_device")
        inputBuilder2.trySetValue("andDontOverwriteThisEither", "bro")
        let input2 = try inputBuilder2.build().get()

        var inputMultiBuilder = LDMultiContextBuilder()
        inputMultiBuilder.addContext(input1)
        inputMultiBuilder.addContext(input2)
        let inputMulti = try inputMultiBuilder.build().get()

        let outputContext = underTest.modifyContext(inputMulti)

        // Ensure we didn't remove them from the existing context.
        XCTAssertEqual(2, outputContext.contextKeys().count)
        XCTAssertTrue(outputContext.isMulti())
        XCTAssertEqual(inputMulti, outputContext)
    }

    /**
     * Requirement 1.2.6.3 - Generated keys are consistent
     */
    func testGeneratesConsistentContextAcrossMultipleCalls() throws {
        let underTest = AutoEnvContextModifier(environmentReporter: EnvironmentReportingMock())

        var inputBuilder = LDContextBuilder(key: "aKey")
        inputBuilder.kind("aKind")
        inputBuilder.trySetValue("dontOverwriteMeBro", "really bro")
        let input = try inputBuilder.build().get()

        let outputContext1 = underTest.modifyContext(input)
        let outputContext2 = underTest.modifyContext(input)

        XCTAssertEqual(outputContext1, outputContext2)
    }

    func testGeneratedLdApplicationKey() throws {
        let underTest = AutoEnvContextModifier(environmentReporter: EnvironmentReportingMock())
        var inputBuilder = LDContextBuilder(key: "aKey")
        inputBuilder.kind("aKind")
        let input = try inputBuilder.build().get()
        let outputContext = underTest.modifyContext(input)
        let outputKey = outputContext.contexts.first(where: { $0.kind == Kind("ld_application") })!.getValue(Reference("key"))
        // expected key is the hash of the concatanation of id and version
        let expectedKey = Util.sha256("idStub").base64UrlEncodedString.toLDValue()
        XCTAssertEqual(expectedKey, outputKey)
    }

    func testGeneratedLdApplicationKeyWithVersionMissing() throws {
        var info = ApplicationInfo()
        info.applicationIdentifier("myID")
        // version is intentionally omitted
        let reporter = ApplicationInfoEnvironmentReporter(info)
        let underTest = AutoEnvContextModifier(environmentReporter: reporter)
        var inputBuilder = LDContextBuilder(key: "aKey")
        inputBuilder.kind("aKind")
        let input = try inputBuilder.build().get()
        let outputContext = underTest.modifyContext(input)
        let outputKey = outputContext.contexts.first(where: { $0.kind == Kind("ld_application") })!.getValue(Reference("key"))
        // expect version to be dropped for hashing
        let expectedKey = Util.sha256("myID").base64UrlEncodedString.toLDValue()
        XCTAssertEqual(expectedKey, outputKey)
    }
}
