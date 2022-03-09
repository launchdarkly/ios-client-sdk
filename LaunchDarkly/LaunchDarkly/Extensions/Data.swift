import Foundation

extension Data {
    var base64UrlEncodedString: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }

    var jsonDictionary: [String: Any]? {
        try? JSONSerialization.jsonDictionary(with: self, options: [.allowFragments])
    }
}
