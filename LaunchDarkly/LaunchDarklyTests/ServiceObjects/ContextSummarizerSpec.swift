import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ContextSummarizerSpec: QuickSpec {
    override func spec() {
        describe("ContextSummarizer") {
            var summarizer: ContextSummarizer!
            var logger: OSLog!
            var context1: LDContext!
            var context2: LDContext!
            var featureFlag: FeatureFlag!

            beforeEach {
                logger = OSLog(subsystem: "com.launchdarkly.test", category: "test")
                summarizer = ContextSummarizer(logger: logger)
                context1 = LDContext.stub()
                context2 = LDContext(key: "user-key-2", kind: "user", name: "Test User 2")
                featureFlag = FeatureFlag.stub()
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
                        var anonymousContext = LDContext(key: "anon-key", kind: "user")
                        anonymousContext.anonymous = true

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
                    let multiContext = try! LDContext.createMulti(contexts: [
                        LDContext(key: "user-1", kind: "user"),
                        LDContext(key: "org-1", kind: "org")
                    ])

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
                    let multiContext1 = try! LDContext.createMulti(contexts: [
                        LDContext(key: "user-1", kind: "user"),
                        LDContext(key: "org-1", kind: "org")
                    ])
                    let multiContext2 = try! LDContext.createMulti(contexts: [
                        LDContext(key: "user-2", kind: "user"),
                        LDContext(key: "org-2", kind: "org")
                    ])

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
