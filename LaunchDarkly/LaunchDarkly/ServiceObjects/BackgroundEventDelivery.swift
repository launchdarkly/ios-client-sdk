import Foundation
import OSLog

/// Writes and delivers the events of every environment as the application goes to the background.
///
/// One for all environments rather than one per client, so that backgrounding takes one background activity assertion
/// however many environments there are, and reaches only the clients started now: a closed client the application
/// still holds is not among them.
///
/// On every platform that notifies the SDK, events are made durable before the notification returns: the OS may kill a
/// backgrounded application without warning, and macOS, which suspends nothing, can still quit or kill it. Where a
/// backgrounded process is suspended once idle, they are also delivered, under the assertion, which is released once
/// every environment has answered. What does not get out is on disk for the next launch where events persist, and
/// otherwise only in memory.
final class BackgroundEventDelivery {
    struct Environment {
        let name: String
        let eventProcessor: EventProcessor
        let logger: OSLog
    }

    /// The environments started now, read at each backgrounding.
    private let environments: () -> [Environment]
    private let suspendsWhenBackgrounded: Bool
    private let activity: BackgroundActivity
    /// How long the deliveries have to answer before the ones that have not count as undelivered. The activity holds
    /// one assertion at a time, so a delivery that never answered would otherwise keep every later backgrounding from
    /// delivering at all.
    private let answerTimeout: TimeInterval

    init(environments: @escaping () -> [Environment],
         suspendsWhenBackgrounded: Bool,
         activity: BackgroundActivity,
         answerTimeout: TimeInterval = BackgroundActivity.maximumDuration) {
        self.environments = environments
        self.suspendsWhenBackgrounded = suspendsWhenBackgrounded
        self.activity = activity
        self.answerTimeout = answerTimeout
    }

    convenience init(environments: @escaping () -> [Environment]) {
        self.init(environments: environments,
                  suspendsWhenBackgrounded: SystemCapabilities.suspendsWhenBackgrounded,
                  activity: BackgroundActivity(reason: "LaunchDarkly event delivery",
                                               logger: environments().first?.logger ?? .disabled))
    }

    /// Commits every environment before returning, at `.deferred` too, and where the process is about to be suspended
    /// starts their deliveries.
    func applicationDidEnterBackground() {
        let environments = self.environments()
        environments.forEach { $0.eventProcessor.commitWherePersisting() }
        guard suspendsWhenBackgrounded, !environments.isEmpty
        else { return }
        activity.run { [weak self] finished in
            guard let self
            else {
                finished()
                return
            }
            environments.map(\.eventProcessor).flushReportingOutcomes(deadline: .now() + self.answerTimeout) { delivered in
                self.logUndelivered(zip(environments, delivered).filter { !$0.1 }.map(\.0))
                finished()
            }
        }
    }

    /// At info for the environments where nothing persists, since their events are lost if the application is
    /// terminated while suspended. Whether events persist is each store's answer rather than the configuration's: a
    /// store that failed to write has stopped persisting.
    private func logUndelivered(_ environments: [Environment]) {
        guard let logger = environments.first?.logger
        else { return }
        let onDisk = environments.filter { ($0.eventProcessor as? DirectEventProcessor)?.store.isPersisting == true }
        let inMemory = environments.filter { ($0.eventProcessor as? DirectEventProcessor)?.store.isPersisting != true }
        if !onDisk.isEmpty {
            os_log("%s events of %s did not reach LaunchDarkly before suspension; they remain on disk for the next launch",
                   log: logger, type: .debug, typeName(and: #function), BackgroundEventDelivery.names(onDisk))
        }
        if !inMemory.isEmpty {
            os_log("%s events of %s did not reach LaunchDarkly before suspension; they are only in memory and are lost if the application is terminated",
                   log: logger, type: .info, typeName(and: #function), BackgroundEventDelivery.names(inMemory))
        }
    }

    private static func names(_ environments: [Environment]) -> String {
        environments.map(\.name).sorted().joined(separator: ", ")
    }
}

extension BackgroundEventDelivery: TypeIdentifying { }
