import Foundation

extension Crc32 {
    /// Advance the current checksum with bytes already in memory, without wrapping them in `Data` first.
    /// - parameter bytes: bytes to advance the checksum
    mutating func advance(withBytes bytes: UnsafeRawBufferPointer) {
        guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
        else { return }
        if let fastCrc32 = Crc32.zLibCrc32 {
            checksum = fastCrc32(checksum, base, UInt32(bytes.count))
        } else {
            checksum = slowCrc32(start: checksum, data: Data(bytes))
        }
    }
}
