import Foundation

#if os(Linux) || os(Windows)
import FoundationNetworking
#endif

extension URLResponse {
    var httpStatusCode: Int? { (self as? HTTPURLResponse)?.statusCode }
    var httpHeaderEtag: String? { (self as? HTTPURLResponse)?.headerEtag }
}
