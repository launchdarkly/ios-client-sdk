import Foundation

extension Date {
    var millisSince1970: Int64 {
        Int64(floor(self.timeIntervalSince1970 * 1_000))
    }

    init?(millisSince1970: Int64?) {
        guard let millisSince1970 = millisSince1970, millisSince1970 >= 0
        else { return nil }
        self = Date(timeIntervalSince1970: Double(millisSince1970) / 1_000)
    }
}
