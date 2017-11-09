//
//  LDUserCacheSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import Darkly

final class LDUserCacheSpec: QuickSpec {
    //swiftlint:disable:next function_body_length
    override func spec() {
        var subject: LDUserCache!
        beforeEach {
            subject = LDUserCache()
            subject.clearAllUsersForTesting()
        }

        describe("init") {
            context("with max users") {
                var maxUsers: Int!
                beforeEach {
                    maxUsers = LDUserCache.Constants.maxUsers + 1

                    subject = LDUserCache(maxUsers: maxUsers)
                }
                it("creates a user cache with max users set to the parameter value") {
                    expect(subject.maxUsers) == maxUsers
                }
            }
            context("without max users") {
                beforeEach {
                    subject = LDUserCache()
                }
                it("creates a user cache with max users set to the default value") {
                    expect(subject.maxUsers) == LDUserCache.Constants.maxUsers
                }
            }
        }

        describe("store and retrieve user") {
            var userStub: LDUser!
            var retrievedUser: LDUser?
            beforeEach {
                userStub = LDUser.stub()
                subject.store(user: userStub)

                retrievedUser = subject.retrieve(userKey: userStub.key)
            }
            it("retrieves user that has matching key") {
                expect({ retrievedUser?.matches(user: userStub) ?? .failed(reason: "failed to retrieve user") }).to(match())
            }
        }

        describe("store and retrieve user as data") {
            var userStub: LDUser!
            var retrievedUser: LDUser?
            beforeEach {
                userStub = LDUser.stub()
                subject.storeUserAsDataForTesting(user: userStub)

                retrievedUser = subject.retrieve(userKey: userStub.key)
            }
            it("retrieves user that has matching key") {
                expect({ retrievedUser?.matches(user: userStub) ?? .failed(reason: "failed to retrieve user") }).to(match())
            }
        }

        describe("retrieveLatest") {
            var retrievedUser: LDUser?
            context("when there are cached users") {
                var latestUser: LDUser!
                beforeEach {
                    let userStubs = subject.stubAndStoreUsers(count: 3)
                    latestUser = userStubs.last

                    retrievedUser = subject.retrieveLatest()
                }
                it("retrieves the user with the latest last updated time") {
                    expect({ retrievedUser?.matches(user: latestUser) ?? .failed(reason: "failed to retrieve user") }).to(match())
                }
            }
            context("when there are no cached users") {
                beforeEach {
                    retrievedUser = subject.retrieveLatest()
                }
                it("returns nil") {
                    expect(retrievedUser).to(beNil())
                }
            }
        }

        describe("store user") {
            context("when max users already stored") {
                var userStubs: [LDUser]!
                var retrievedUser: LDUser?
                beforeEach {
                    userStubs = subject.stubAndStoreUsers(count: subject.maxUsers + 1)
                }
                it("stores the user and removes the oldest user from the cache") {
                    for index in 0..<userStubs.count {
                        retrievedUser = subject.retrieve(userKey: userStubs[index].key)
                        if index == 0 {
                            expect(retrievedUser).to(beNil())
                        }
                        else {
                            expect({ retrievedUser?.matches(user: userStubs[index]) ?? .failed(reason: "failed to retrieve user") }).to(match())
                        }
                    }
                }
            }
        }
    }
}

extension LDUserCache {
    func stubAndStoreUsers(count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        while userStubs.count < count {
            let newUser = LDUser.stub()
            userStubs.append(newUser)
            self.store(user: newUser)
        }
        return userStubs
    }
}

extension LDUser {
    //swiftlint:disable:next cyclomatic_complexity
    fileprivate func matches(user otherUser: LDUser) -> ToMatchResult {
        var messages = [String]()
        if key != otherUser.key { messages.append("key equals \(key)") }
        if name != otherUser.name { messages.append("name equals \(name ?? "<nil>")") }
        if firstName != otherUser.firstName { messages.append("firstName equals \(firstName ?? "<nil>")") }
        if lastName != otherUser.lastName { messages.append("lastName equals \(lastName ?? "<nil>")") }
        if isAnonymous != otherUser.isAnonymous { messages.append("isAnonymous equals \(isAnonymous)") }
        if country != otherUser.country { messages.append("country equals \(country ?? "<nil>")") }
        if ipAddress != otherUser.ipAddress { messages.append("ipAddress equals \(ipAddress ?? "<nil>")") }
        if email != otherUser.email { messages.append("email equals \(email ?? "<nil>")") }
        if avatar != otherUser.avatar { messages.append("avatar equals \(avatar ?? "<nil>")") }
        if custom != otherUser.custom { messages.append("custom equals \(custom?.description ?? "<nil>")") }
        if device != otherUser.device { messages.append("device equals \(device ?? "<nil>")") }
        if operatingSystem != otherUser.operatingSystem { messages.append("operatingSystem equals \(operatingSystem ?? "<nil>")") }
        if lastUpdated.jsonDate != otherUser.lastUpdated.jsonDate { messages.append("lastUpdated equals \(lastUpdated.jsonDate)") }
        if flagStore.featureFlags != otherUser.flagStore.featureFlags { messages.append("featureFlags equals \(flagStore.featureFlags)") }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }
}
