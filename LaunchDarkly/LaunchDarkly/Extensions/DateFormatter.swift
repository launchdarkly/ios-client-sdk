import Foundation

extension DateFormatter {
    static var httpUrlHeaderFormatter: DateFormatter {
        let httpUrlHeaderFormatter = DateFormatter()
        httpUrlHeaderFormatter.locale = Locale(identifier: "en_US_POSIX")
        httpUrlHeaderFormatter.timeZone = TimeZone(abbreviation: "GMT")
        httpUrlHeaderFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"     // Mon, 07 May 2018 19:46:29 GMT

        return httpUrlHeaderFormatter
    }
}
