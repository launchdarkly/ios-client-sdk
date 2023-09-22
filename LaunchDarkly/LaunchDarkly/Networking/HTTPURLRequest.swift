import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

extension URLRequest {
    struct HTTPMethods {
        static let get = "GET"
        static let post = "POST"
        static let report = "REPORT"
    }
}
