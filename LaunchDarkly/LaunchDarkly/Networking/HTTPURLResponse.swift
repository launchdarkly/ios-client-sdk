import Foundation

extension HTTPURLResponse {

    struct HeaderKeys {
        static let date = "Date"
        static let etag = "Etag"
    }

    struct StatusCodes {
        // swiftlint:disable:next identifier_name
        static let ok = 200
        static let accepted = 202
        static let notModified = 304
        static let badRequest = 400
        static let unauthorized = 401
        static let methodNotAllowed = 405
        static let requestTimeout = 408
        static let tooManyRequests = 429
        static let internalServerError = 500
        static let notImplemented = 501

        // The 4xx statuses the SDK keeps retrying on. Any other 4xx is terminal.
        static let recoverableClientErrors = [badRequest, requestTimeout, tooManyRequests]

        // Returns true for a 4xx status the SDK should not retry.
        static func isTerminalStatusCode(_ statusCode: Int) -> Bool {
            (400..<500).contains(statusCode) && !recoverableClientErrors.contains(statusCode)
        }
    }

    var headerDate: Date? {
        guard let dateHeader = self.allHeaderFields[HeaderKeys.date] as? String
        else { return nil }
        return DateFormatter.httpUrlHeaderFormatter.date(from: dateHeader)
    }

    var headerEtag: String? {
        self.allHeaderFields[HeaderKeys.etag] as? String
    }
}
