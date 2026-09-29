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
                    // The summarizer stores the context as given; that a summary redacts the attributes of an
                    // anonymous context is decided when the event is encoded, by `redactsAnonymousAttributes`.
                    // Asserting the encoded output rather than the stored flag keeps this pinned to the behaviour.
                    it("redacts the attributes of an anonymous context when the summary is encoded") {
                        var builder = LDContextBuilder(key: "anon-key")
                        builder.anonymous(true)
                        _ = builder.trySetValue("email", "anon@example.com")
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

                        let event = SummaryEvent(flagRequestTracker: summaries[0].tracker, context: summaries[0].context)
                        expect(event.redactsAnonymousAttributes) == true

                        let encoded = String(data: try! JSONEncoder().encode(event), encoding: .utf8) ?? ""
                        expect(encoded.contains("anon@example.com")) == false
                        expect(encoded.contains("redactedAttributes")) == true
                    }

                    // Neither `==` nor `contextHash()`, which the summarizer used to key by, tells these apart, so they
                    // share the summary of whichever arrived first.
                    it("shares one summary between contexts that spell a private attribute differently") {
                        func context(privateAttribute: String) -> LDContext {
                            var builder = LDContextBuilder(key: "user-key")
                            _ = builder.trySetValue("email", "a@example.com")
                            builder.addPrivateAttribute(Reference(privateAttribute))
                            return try! builder.build().get()
                        }
                        let plain = context(privateAttribute: "email")
                        let slashed = context(privateAttribute: "/email")
                        expect(plain) == slashed
                        expect(plain.contextHash()) == slashed.contextHash()

                        for context in [slashed, plain, slashed] {
                            summarizer.trackRequest(flagKey: "flag1", reportedValue: .bool(true), featureFlag: featureFlag,
                                                    defaultValue: .bool(false), context: context)
                        }

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 1
                        expect(summaries[0].context.privateAttributes.map { $0.raw() }) == ["/email"]
                    }

                    // `contextHash()` saw only whether there are private attributes, not which.
                    it("separates contexts by whether they have private attributes, not by which") {
                        func context(privateAttributes: [String]) -> LDContext {
                            var builder = LDContextBuilder(key: "user-key")
                            builder.name("a")
                            _ = builder.trySetValue("email", "a@example.com")
                            privateAttributes.forEach { builder.addPrivateAttribute(Reference($0)) }
                            return try! builder.build().get()
                        }
                        let none = context(privateAttributes: [])
                        let email = context(privateAttributes: ["email"])
                        let name = context(privateAttributes: ["name"])
                        expect(email) != name
                        expect(email.contextHash()) == name.contextHash()
                        expect(none.contextHash()) != email.contextHash()

                        for context in [email, none, name] {
                            summarizer.trackRequest(flagKey: "flag1", reportedValue: .bool(true), featureFlag: featureFlag,
                                                    defaultValue: .bool(false), context: context)
                        }

                        let privateSets = summarizer.getSummaries().map { Set($0.context.privateAttributes.map { $0.raw() }) }
                        expect(Set(privateSets)) == [[], ["email"]]
                    }
                }

                // JSON cannot represent these, so `contextHash()` fell back to the fully qualified key.
                context("attributes holding NaN or an infinity") {
                    func context(key: String = "user-key", name: String, score: Double) -> LDContext {
                        var builder = LDContextBuilder(key: key)
                        builder.name(name)
                        _ = builder.trySetValue("score", .number(score))
                        return try! builder.build().get()
                    }
                    func track(_ contexts: [LDContext]) {
                        for context in contexts {
                            summarizer.trackRequest(flagKey: "flag1", reportedValue: .bool(true), featureFlag: featureFlag,
                                                    defaultValue: .bool(false), context: context)
                        }
                    }

                    it("keeps one summary for a context holding NaN, though separately built copies are not equal") {
                        let copies = (0..<3).map { _ in context(name: "a", score: .nan) }
                        expect(copies[0]) != copies[1]

                        track(copies)

                        expect(summarizer.getSummaries().count) == 1
                    }

                    it("shares one summary between unrepresentable contexts with the same key") {
                        let nan = context(name: "a", score: .nan)
                        let infinity = context(name: "b", score: .infinity)
                        expect(nan.contextHash()) == infinity.contextHash()

                        track([nan, infinity])

                        let summaries = summarizer.getSummaries()
                        expect(summaries.count) == 1
                        expect(summaries[0].context.getValue(Reference("name"))) == .string("a")
                    }

                    it("separates unrepresentable contexts with different keys") {
                        let first = context(key: "key-1", name: "a", score: .nan)
                        let second = context(key: "key-2", name: "a", score: .nan)
                        expect(first.contextHash()) != second.contextHash()

                        track([first, second])

                        expect(summarizer.getSummaries().count) == 2
                    }

                    it("separates an unrepresentable context from a representable one with the same key") {
                        let nan = context(name: "a", score: .nan)
                        let finite = context(name: "a", score: 1)
                        expect(nan.contextHash()) != finite.contextHash()

                        track([nan, finite, nan])

                        expect(summarizer.getSummaries().count) == 2
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

            describe("maxContexts") {
                func track(_ summarizer: ContextSummarizer, key: String) -> Bool {
                    summarizer.trackRequest(flagKey: "flag1", reportedValue: .bool(true), featureFlag: featureFlag,
                                            defaultValue: .bool(false), context: LDContext.stub(key: key))
                }

                it("turns away an evaluation for a new context once the limit is reached") {
                    let bounded = ContextSummarizer(logger: logger, maxContexts: 2)
                    expect(track(bounded, key: "a")) == true
                    expect(track(bounded, key: "b")) == true

                    expect(track(bounded, key: "c")) == false
                    expect(bounded.getSummaries().map { $0.context.fullyQualifiedKey() }.sorted()) == ["a", "b"]
                }

                it("still counts evaluations for a context already counted") {
                    let bounded = ContextSummarizer(logger: logger, maxContexts: 1)
                    expect(track(bounded, key: "a")) == true
                    expect(track(bounded, key: "b")) == false

                    expect(track(bounded, key: "a")) == true
                    let counters = bounded.getSummaries().first?.tracker.flagCounters["flag1"]?.flagValueCounters
                    expect(counters?.values.reduce(0) { $0 + $1.count }) == 2
                }

                it("makes room again once cleared") {
                    let bounded = ContextSummarizer(logger: logger, maxContexts: 1)
                    expect(track(bounded, key: "a")) == true
                    expect(track(bounded, key: "b")) == false

                    bounded.clear()

                    expect(track(bounded, key: "b")) == true
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
