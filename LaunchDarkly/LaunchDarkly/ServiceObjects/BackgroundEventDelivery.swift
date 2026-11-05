import Foundation
import OSLog

/// What an environment's events do as the application goes to the background.
///
/// On every platform that notifies the SDK, they are made durable before the notification returns: the OS may kill a backgrounded
/// application without warning, and macOS, which suspends nothing, can still quit or kill it. Where a backgrounded
/// process is suspended once idle, they are also delivered, under a background activity assertion. What does not get
/// out is on disk for the next launch where events persist, and otherwise only in memory.
final class BackgroundEventDelivery {
    private let eventProcessor: EventProcessor
    private let suspendsWhenBackgrounded: Bool
    /// One assertion per client, however many times the application is backgrounded while a delivery is running.
    private let activity: BackgroundActivity
    private let logger: OSLog

    init(eventProcessor: EventProcessor, suspendsWhenBackgrounded: Bool, activity: BackgroundActivity, logger: OSLog) {
        self.eventProcessor = eventProcessor
        self.suspendsWhenBackgrounded = suspendsWhenBackgrounded
        self.activity = activity
        self.logger = logger
    }

    convenience init(eventProcessor: EventProcessor, logger: OSLog) {
        self.init(eventProcessor: eventProcessor,
                  suspendsWhenBackgrounded: SystemCapabilities.suspendsWhenBackgrounded,
                  activity: BackgroundActivity(reason: "LaunchDarkly event delivery", logger: logger),
                  logger: logger)
    }

    /// Commits before returning, at `.deferred` too, and where the process is about to be suspended starts a delivery.
    func applicationDidEnterBackground() {
        eventProcessor.commitWherePersisting()
        guard suspendsWhenBackgrounded
        else { return }
        activity.run { [weak self] finished in
            guard let self
            else {
                finished()
                return
            }
            self.eventProcessor.flushReportingOutcome { delivered in
                if !delivered {
                    self.logUndelivered()
                }
                finished()
            }
        }
    }

    /// At info where nothing persists, since the events are lost if the application is terminated while suspended.
    /// Whether events persist is the store's answer rather than the configuration's: a store that failed to write has
    /// stopped persisting.
    private func logUndelivered() {
        if (eventProcessor as? DirectEventProcessor)?.store.isPersisting == true {
            os_log("%s events did not reach LaunchDarkly before suspension; they remain on disk for the next launch",
                   log: logger, type: .debug, typeName(and: #function))
        } else {
            os_log("%s events did not reach LaunchDarkly before suspension; they are only in memory and are lost if the application is terminated",
                   log: logger, type: .info, typeName(and: #function))
        }
    }
}

extension BackgroundEventDelivery: TypeIdentifying { }
