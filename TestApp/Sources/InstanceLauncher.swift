import Foundation
#if os(macOS)
import AppKit
#endif

/// Starts another instance of this app on a Mac, so several processes share one event directory.
///
/// Each instance has its own open log; a batch any of them closes can be delivered by any other, and a log one left
/// behind when it was killed is recovered by the next client that starts. `scripts/launch-instances.sh` does the same
/// from a terminal.
enum InstanceLauncher {
    static var isAvailable: Bool {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    static var processId: Int32 {
        ProcessInfo.processInfo.processIdentifier
    }

    /// Returns a message describing what happened, for the result line.
    static func launchAnother() -> String {
        #if os(macOS)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = forwardedArguments
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        return "Launching another instance"
        #elseif targetEnvironment(macCatalyst)
        // Neither NSWorkspace nor Process is available to a Catalyst app; open(1) is what starts a new instance.
        let arguments = ["/usr/bin/open", "-n", Bundle.main.bundlePath]
            + (forwardedArguments.isEmpty ? [] : ["--args"] + forwardedArguments)
        var argv = arguments.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var pid: pid_t = 0
        let status = posix_spawn(&pid, arguments[0], nil, nil, &argv, environ)
        return status == 0 ? "Launching another instance" : "Could not launch another instance: \(String(cString: strerror(status)))"
        #else
        return "Only a Mac runs several instances of an app"
        #endif
    }

    /// The `-LDMobileKey` and `-LDEnvironment` overrides this instance was launched with, so the next one talks to the
    /// same environment.
    private static var forwardedArguments: [String] {
        var forwarded: [String] = []
        for key in ["LDMobileKey", "LDEnvironment"] {
            if let value = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)[key] as? String {
                forwarded += ["-\(key)", value]
            }
        }
        return forwarded
    }
}
