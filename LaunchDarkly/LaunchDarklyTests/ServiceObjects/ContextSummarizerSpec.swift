import Foundation
import Quick
import Nimble
import OSLog
@testable import LaunchDarkly

final class ContextSummarizerSpec: QuickSpec {
    override func spec() {
        describe("ContextSummarizer") {
            var summarizer: ContextSummarizer!
            var logger: OSLog!
            var context1: LDContext!
            var context2: LDContext!
            var featureFlag: FeatureFlag?

            beforeEach {
                logger = OSLog(subsystem: "com.launchdarkly.test", category: "test")
                summarizer = ContextSummarizer(logger: logger)
                // Create two different contexts for testing
                context1 = LDContext.stub()
                var builder2 = LDContextBuilder(key: "user-key-2")
                builder2.name("Test User 2")
                context2 = try! builder2.build().get()
                featureFlag = FeatureFlag(flagKey: "test-flag", value: .bool(true), variation: 1, flagVersion: 1, trackEvents: false)
            }

            describe("trackRequest") {
                context("single context") {
                    it("creates a tracker for the context") {
                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context1
                        )

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 1
                        expect(summaries[0].tracker.hasLoggedRequests) == true
                    }

                    it("tracks multiple flag evaluations for same context") {
                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context1
                        )
                        summarizer.trackRequest(
                            flagKey: "flag2",
                            reportedValue: .string("value"),
                            featureFlag: featureFlag,
                            defaultValue: .string("default"),
                            context: context1
                        )

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 1
                        expect(summaries[0].tracker.flagCounters.count) == 2
                    }
                }

                context("multiple contexts") {
                    it("creates separate trackers for different contexts") {
                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context1
                        )
                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(false),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context2
                        )

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 2
                    }

                    it("reuses tracker when same context is used again") {
                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context1
                        )
                        summarizer.trackRequest(
                            flagKey: "flag2",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context2
                        )
                        summarizer.trackRequest(
                            flagKey: "flag3",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: context1
                        )

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 2

                        let context1Summaries = summaries.filter { $0.context.contextHash() == context1.contextHash() }
                        expect(context1Summaries.count) == 1
                        expect(context1Summaries[0].tracker.flagCounters.count) == 2
                    }
                }

                context("context privacy") {
                    it("stores filtered context with redactAnonymousAttributes flag") {
                        var builder = LDContextBuilder(key: "anon-key")
                        builder.anonymous(true)
                        let anonymousContext = try! builder.build().get()

                        summarizer.trackRequest(
                            flagKey: "flag1",
                            reportedValue: .bool(true),
                            featureFlag: featureFlag,
                            defaultValue: .bool(false),
                            context: anonymousContext
                        )

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 1
                        expect(summaries[0].context.redactAnonymousAttributes) == true
                    }
                }
            }

            describe("getSummaries") {
                it("returns empty array when no requests tracked") {
                    let summaries = summarizer.getSummaries()
                    expect(summaries.count) == 0
                }

                it("returns correct tracker-context pairs") {
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context1
                    )
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(false),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context2
                    )

                    let summaries = summarizer.getSummaries()
                    expect(summaries.count) == 2

                    let contextHashes = summaries.map { $0.context.contextHash() }
                    expect(contextHashes).to(contain(context1.contextHash()))
                    expect(contextHashes).to(contain(context2.contextHash()))
                }
            }

            describe("hasLoggedRequests") {
                it("returns false when no requests tracked") {
                    expect(summarizer.hasLoggedRequests) == false
                }

                it("returns true when requests have been tracked") {
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context1
                    )

                    expect(summarizer.hasLoggedRequests) == true
                }

                it("returns true when any tracker has logged requests") {
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context1
                    )
                    summarizer.trackRequest(
                        flagKey: "flag2",
                        reportedValue: .bool(false),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context2
                    )

                    expect(summarizer.hasLoggedRequests) == true
                }
            }

            describe("clear") {
                it("removes all trackers") {
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context1
                    )
                    summarizer.trackRequest(
                        flagKey: "flag2",
                        reportedValue: .bool(false),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context2
                    )

                    expect(summarizer.hasLoggedRequests) == true
                    expect(summarizer.getSummaries().count) == 2

                    summarizer.clear()

                    expect(summarizer.hasLoggedRequests) == false
                    expect(summarizer.getSummaries().count) == 0
                }

                it("allows tracking new requests after clear") {
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context1
                    )
                    summarizer.clear()

                    summarizer.trackRequest(
                        flagKey: "flag2",
                        reportedValue: .bool(false),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: context2
                    )

                    expect(summarizer.hasLoggedRequests) == true
                    expect(summarizer.getSummaries().count) == 1
                    expect(summarizer.getSummaries()[0].context.contextHash()) == context2.contextHash()
                }
            }

            describe("multi-context support") {
                it("handles multi-kind contexts correctly") {
                    var userBuilder = LDContextBuilder(key: "user-1")
                    userBuilder.kind("user")
                    let userContext = try! userBuilder.build().get()

                    var orgBuilder = LDContextBuilder(key: "org-1")
                    orgBuilder.kind("org")
                    let orgContext = try! orgBuilder.build().get()

                    var multiBuilder = LDMultiContextBuilder()
                    multiBuilder.addContext(userContext)
                    multiBuilder.addContext(orgContext)
                    let multiContext = try! multiBuilder.build().get()

                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: multiContext
                    )

                    let summaries = summarizer.getSummaries()
                    expect(summaries.count) == 1
                    expect(summaries[0].context.contextHash()) == multiContext.contextHash()
                }

                it("treats different multi-contexts as separate") {
                    var user1Builder = LDContextBuilder(key: "user-1")
                    user1Builder.kind("user")
                    let user1Context = try! user1Builder.build().get()

                    var org1Builder = LDContextBuilder(key: "org-1")
                    org1Builder.kind("org")
                    let org1Context = try! org1Builder.build().get()

                    var multi1Builder = LDMultiContextBuilder()
                    multi1Builder.addContext(user1Context)
                    multi1Builder.addContext(org1Context)
                    let multiContext1 = try! multi1Builder.build().get()

                    var user2Builder = LDContextBuilder(key: "user-2")
                    user2Builder.kind("user")
                    let user2Context = try! user2Builder.build().get()

                    var org2Builder = LDContextBuilder(key: "org-2")
                    org2Builder.kind("org")
                    let org2Context = try! org2Builder.build().get()

                    var multi2Builder = LDMultiContextBuilder()
                    multi2Builder.addContext(user2Context)
                    multi2Builder.addContext(org2Context)
                    let multiContext2 = try! multi2Builder.build().get()

                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(true),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: multiContext1
                    )
                    summarizer.trackRequest(
                        flagKey: "flag1",
                        reportedValue: .bool(false),
                        featureFlag: featureFlag,
                        defaultValue: .bool(false),
                        context: multiContext2
                    )

                    let summaries = summarizer.getSummaries()
                    expect(summaries.count) == 2
                }
            }
        }
    }
}
