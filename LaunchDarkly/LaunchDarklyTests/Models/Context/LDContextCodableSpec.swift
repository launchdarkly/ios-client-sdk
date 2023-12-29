import Foundation
import XCTest

@testable import LaunchDarkly

final class LDContextCodableSpec: XCTestCase {
    func testUserFormatIsConvertedToSingleContextFormat() throws {
        let testCases = [
            ("{\"key\": \"foo\"}", "{\"key\": \"foo\", \"kind\": \"user\"}"),
            ("{\"key\" : \"foo\", \"name\" : \"bar\"}", "{\"kind\" : \"user\", \"key\" : \"foo\", \"name\" : \"bar\"}"),
            ("{\"key\" : \"foo\", \"custom\" : {\"a\" : \"b\"}}", "{\"kind\" : \"user\", \"key\" : \"foo\", \"a\" : \"b\"}"),
            ("{\"key\" : \"foo\", \"anonymous\" : true}", "{\"kind\" : \"user\", \"key\" : \"foo\", \"anonymous\" : true}"),
            ("{\"key\" : \"foo\"}", "{\"kind\" : \"user\", \"key\" : \"foo\"}"),
            ("{\"key\" : \"foo\", \"ip\" : \"1\", \"privateAttributeNames\" : [\"ip\"]}", "{\"kind\" : \"user\", \"key\" : \"foo\", \"ip\" : \"1\", \"_meta\" : { \"privateAttributes\" : [\"ip\"]} }")
        ]

        for (userJson, explicitFormat) in testCases {
            let userContext = try JSONDecoder().decode(LDContext.self, from: Data(userJson.utf8))
            let explicitContext = try JSONDecoder().decode(LDContext.self, from: Data(explicitFormat.utf8))

            XCTAssertEqual(userContext, explicitContext)
        }
    }

    func testUserCustomAttributesAreOverriddenByOldBuiltIns() throws {
        let userJson = "{\"key\" : \"foo\", \"anonymous\" : true, \"secondary\": \"my secondary\", \"custom\": {\"anonymous\": false, \"secondary\": \"custom secondary\"}}"
        // Secondary is not supported, so we should get the custom version for that.
        let explicitFormat = "{\"kind\" : \"user\", \"key\" : \"foo\", \"anonymous\" : true, \"secondary\": \"custom secondary\"}"

        let userContext = try JSONDecoder().decode(LDContext.self, from: Data(userJson.utf8))
        let explicitContext = try JSONDecoder().decode(LDContext.self, from: Data(explicitFormat.utf8))

        XCTAssertEqual(userContext, explicitContext)
    }

    func testSingleContextKindsAreDecodedAndEncodedWithoutLossOfInformation() throws {
        let testCases = [
            "{\"key\":\"foo\",\"kind\":\"org\"}",
            "{\"key\":\"foo\",\"kind\":\"user\"}",
            "{\"anonymous\":true,\"key\":\"bar\",\"kind\":\"foo\"}",
            "{\"_meta\":{\"privateAttributes\":[\"a\"]},\"key\":\"bar\",\"kind\":\"foo\",\"name\":\"Foo\"}",
            "{\"key\":\"bar\",\"kind\":\"foo\",\"object\":{\"a\":\"b\"}}"
        ]

        for json in testCases {
            let context = try JSONDecoder().decode(LDContext.self, from: Data(json.utf8))
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = [.sortedKeys]
            jsonEncoder.userInfo = [LDContext.UserInfoKeys.includePrivateAttributes:true,LDContext.UserInfoKeys.redactAttributes:false]
            let output = try jsonEncoder.encode(context)
            let outputJson = String(data: output, encoding: .utf8)

            XCTAssertEqual(json, outputJson)
        }
    }

    func testAttributeRetractionWorksCorrectly() throws {
        let json = """
                   {
                       "kind":"foo",
                       "key":"bar",
                       "name":"Foo",
                       "a": "should be removed",
                       "b": {
                           "c": "should be removed",
                           "d": "should be retained"
                       },
                       "/complex/attribute": "should be removed",
                       "_meta":{
                           "privateAttributes":["a", "/b/c", "~1complex~1attribute"],
                       }
                   }
                   """

        let context = try JSONDecoder().decode(LDContext.self, from: Data(json.utf8))
        let output = try JSONEncoder().encode(context)
        let outputJson = String(data: output, encoding: .utf8)

        XCTAssertTrue(outputJson!.contains("should be retained"))
        XCTAssertFalse(outputJson!.contains("should be removed"))
    }

    func testGlobalAttributeRetractionWorksCorrectly() throws {
        let json = """
                   {
                       "kind":"foo",
                       "key":"bar",
                       "name":"Foo",
                       "a": "should be removed",
                       "b": {
                           "c": "should be removed",
                           "d": "should be retained"
                       },
                       "_meta":{
                           "privateAttributes":["a", "/b/c"],
                       }
                   }
                   """

        let context = try JSONDecoder().decode(LDContext.self, from: Data(json.utf8))

        let encodingConfig: [CodingUserInfoKey: Any] =
        [
            LDContext.UserInfoKeys.globalPrivateAttributes: [Reference("a"), Reference("/b/c")]
        ]
        let encoder = JSONEncoder()
        encoder.userInfo = encodingConfig
        let output = try encoder.encode(context)
        let outputJson = String(data: output, encoding: .utf8)

        XCTAssertTrue(outputJson!.contains("should be retained"))
        XCTAssertFalse(outputJson!.contains("should be removed"))
    }

    func testCanDecodeIntoMultiContextCorrectly() throws {
        let json = """
                   {
                        "kind": "multi",
                        "user": {
                            "key": "foo-key",
                        },
                        "bar": {
                            "key": "bar-key"
                        },
                        "baz": {
                            "key": "baz-key",
                            "anonymous": true
                       }
                   }
                   """
        let context = try JSONDecoder().decode(LDContext.self, from: Data(json.utf8))

        let userBuilder = LDContextBuilder(key: "foo-key")
        var barBuilder = LDContextBuilder(key: "bar-key")
        barBuilder.kind("bar")

        var bazBuilder = LDContextBuilder(key: "baz-key")
        bazBuilder.kind("baz")
        bazBuilder.anonymous(true)

        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(try userBuilder.build().get())
        multiBuilder.addContext(try barBuilder.build().get())
        multiBuilder.addContext(try bazBuilder.build().get())
        let expectedContext = try multiBuilder.build().get()

        XCTAssertEqual(expectedContext, context)
    }
}
