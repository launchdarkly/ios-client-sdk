import CommonCrypto
import Foundation

class Util {
    internal static let validKindCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    internal static let validTagCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    class func sha256base64(_ str: String) -> String {
        sha256(str).base64EncodedString()
    }

    class func sha256(_ str: String) -> Data {
        let data = Data(str.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }

    /// A name for what is stored for a mobile key, safe in a path and holding neither the key nor the bundle identifier:
    /// the SHA-256 of each, base64url encoded, the bundle's first where there is one.
    class func hashedStorageName(mobileKey: String, bundleId: String? = Bundle.main.bundleIdentifier) -> String {
        let key = sha256(mobileKey).base64UrlEncodedString
        guard let bundleId
        else { return key }
        return "\(sha256(bundleId).base64UrlEncodedString).\(key)"
    }
}

extension String {
    func onlyContainsCharset(_ set: CharacterSet) -> Bool {
        if description.rangeOfCharacter(from: set.inverted) != nil {
            return false
        }

        return true
    }
}
