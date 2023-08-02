import Foundation

class EnvironmentReporterBuilder {
    private var applicationInfo: ApplicationInfo?
    private var collectPlatformTelemetry: Bool = false

     /// Sets the application info that this environment reporter will report when asked in the future, overriding the automatically sourced {@link ApplicationInfo}
    public func applicationInfo(_ applicationInfo: ApplicationInfo) {
        self.applicationInfo = applicationInfo
    }

    /// Enables automatically collecting attributes from the platform.
    public func enableCollectionFromPlatform() {
        collectPlatformTelemetry = true
    }

    func build() -> EnvironmentReporting {
        /**
         * Create chain of responsibility with the following priority order
         * 1. {@link ApplicationInfoEnvironmentReporter} - holds customer override
         * 2. {@link AndroidEnvironmentReporter} - Android platform API next
         * 3. {@link SDKEnvironmentReporter} - Fallback is SDK constants
         */
        var reporters: [EnvironmentReporterChainBase] = []

        if let info = applicationInfo {
            reporters.append(ApplicationInfoEnvironmentReporter(info))
        }

        if collectPlatformTelemetry {
            #if os(iOS)
            reporters.append(IOSEnvironmentReporter())
            #elseif os(watchOS)
            reporters.append(WatchOSEnvironmentReporter())
            #elseif os(OSX)
            reporters.append(MacOSEnvironmentReporter())
            #elseif os(tvOS)
            reporters.append(TVOSEnvironmentReporter())
            #endif
        }

        // always add fallback reporter
        reporters.append(SDKEnvironmentReporter())

        // build chain of responsibility by iterating on all but last element
        for i in reporters.indices.dropLast() {
            reporters[i].setNext(reporters[i + 1])
        }

        // guaranteed non-empty since fallback reporter is always added
        return reporters[0]
    }
}
