import Foundation
#if canImport(SystemConfiguration)
import SystemConfiguration
#endif

// sourcery: autoMockable
/// Answers whether the device has a route to the network at all.
///
/// A protocol rather than a free function so that a test can say what the network is doing, instead of asking the
/// machine it happens to be running on. Without it, anything that reaches for the network reads differently on a
/// laptop that is online, a laptop that is not, and a CI runner behind a proxy.
protocol NetworkReporting {
    func isConnectedToNetwork() -> Bool
}

class NetworkReporter: NetworkReporting {
    #if canImport(SystemConfiguration)
    // Sourced from: https://stackoverflow.com/a/39782859
    func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }

        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }

        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let reachability = (isReachable && !needsConnection)

        return reachability
    }
    #else
    func isConnectedToNetwork() -> Bool { true }
    #endif
}
