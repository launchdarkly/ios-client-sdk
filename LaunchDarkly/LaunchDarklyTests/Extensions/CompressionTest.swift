import XCTest

@testable import LaunchDarkly

extension Data {
    func gzip_gunzip() -> Data? { return c_gzip()?.c_gunzip() }

    func c_gzip() -> Data? { let res: Data? = self.gzip();     XCTAssertNotNil(res, "\(#function) failed"); return res }
    func c_gunzip() -> Data? { let res: Data? = self.gunzip();   XCTAssertNotNil(res, "\(#function) failed"); return res }
}

extension String {
    func gzip_gunzip() -> Data? { return data(using: .ascii)?.gzip_gunzip() }
}

class CompressionTest: XCTestCase {
    static var blob16mb: Data!

    override class func setUp() {
        super.setUp()
        let b = 1024 * 1024 * 16 // 16 MB
        let ints = [UInt32](repeating: 0, count: b / 4).map { _ in arc4random() }
        self.blob16mb = Data(bytes: ints, count: b)
    }

    func testEmptyString() {
        XCTAssertEqual(Data(), "".gzip_gunzip())
    }

    func testEmptyData() {
        XCTAssertEqual(Data(), Data().gzip_gunzip())
    }

    func testCrc32() {
        var crc = Crc32()
        XCTAssertEqual(crc.checksum, 0x0)
        crc.advance(withChunk: "The quick brown ".data(using: .ascii)!)
        crc.advance(withChunk: "fox jumps over ".data(using: .ascii)!)
        crc.advance(withChunk: "the lazy dog.".data(using: .ascii)!)
        XCTAssertEqual(crc.checksum, 0x519025e9)
    }

    func testSlowCrc32MatchesZLib() throws {
        let zLibCrc32 = try XCTUnwrap(Crc32.zLibCrc32)
        let crc = Crc32()
        XCTAssertEqual(crc.slowCrc32(start: 0, data: "The quick brown fox jumps over the lazy dog.".data(using: .ascii)!), 0x519025e9)

        let blob = CompressionTest.blob16mb.prefix(1024 * 1024)
        for size in [0, 1, 2, 3, 4, 7, 8, 15, 16, 31, 64, 255, 256, 1000, 4096, 65_537, blob.count] {
            let data = Data(blob.prefix(size))
            for start: UInt32 in [0, 0x519025e9, 0xffffffff] {
                let fast = data.withUnsafeBytes { bytes -> UInt32 in
                    // Never null: zlib answers 0 for a null buffer whatever the start, where an empty one leaves it.
                    zLibCrc32(start, bytes.bindMemory(to: UInt8.self).baseAddress ?? UnsafePointer(bitPattern: 1)!, UInt32(size))
                }
                XCTAssertEqual(crc.slowCrc32(start: start, data: data), fast, "size \(size), start \(String(format: "%08x", start))")
            }
        }
    }

    func testCrc32AdvanceWithBytesMatchesChunk() {
        let data = Data(CompressionTest.blob16mb.prefix(100_000))
        var chunked = Crc32()
        var unwrapped = Crc32()
        var start = 0
        for size in [0, 1, 7, 4096, 30_000, 65_896] {
            let piece = data.subdata(in: start..<start + size)
            chunked.advance(withChunk: piece)
            piece.withUnsafeBytes { unwrapped.advance(withBytes: $0) }
            start += size
        }

        XCTAssertEqual(start, data.count)
        XCTAssertEqual(chunked.checksum, data.crc32().checksum)
        XCTAssertEqual(unwrapped.checksum, chunked.checksum)
    }

    func testMiscSmall_gzip_gunzip() {
        for i in 1...500 {
            let s = String(repeating: "a", count: i)
            XCTAssertEqual(s.data(using: .ascii), s.gzip_gunzip(), "Fails with: \(s)")
        }
    }

    func testAsciiNumbers_gzip_gunzip() {
        for i in 1...500 {
            let r = sqrt(Double(i)) / .pi
            let s = String(repeating: "\(r)", count: i)
            XCTAssertEqual(s.data(using: .ascii), s.gzip_gunzip(), "Fails with: \(s)")
        }
    }

    func testRandomDataChunks_gzip_gunzip() {
        for i in 1...500 {
            let ints = [UInt32](repeating: 0, count: 1 + (i / 4)).map { _ in arc4random() }
            let data = Data(bytes: ints, count: i)
            XCTAssertEqual(data, data.gzip_gunzip(), "Fails with random data (\(data.count) bytes) :(")
        }
    }

    func testRandomDataBlob_16MB_gzip_gunzip() {
        XCTAssertEqual(CompressionTest.blob16mb, CompressionTest.blob16mb.gzip_gunzip())
    }

    func testGzipCrcFail() {
        let b = 1024 * 16
        let ints = [UInt32](repeating: 0xcafeabee, count: b / 4)
        var zipped_blob = Data(bytes: ints, count: b).gzip()!

        let wrong_crc = Data(bytes: [0xcafeabee], count: 1)
        let range = (zipped_blob.count - 8)..<(zipped_blob.count - 4)
        zipped_blob.replaceSubrange(range, with: wrong_crc)

        XCTAssertNil(zipped_blob.gunzip())
    }

    func testGzipISizeFail() {
        let b = 1024 * 16
        let ints = [UInt32](repeating: 0xcafeabee, count: b / 4)
        var zipped_blob = Data(bytes: ints, count: b).gzip()!

        let wrong_isize = Data(bytes: [0xcafeabee], count: 1)
        let range = (zipped_blob.count - 4)..<(zipped_blob.count)
        zipped_blob.replaceSubrange(range, with: wrong_isize)

        XCTAssertNil(zipped_blob.gunzip())
    }
}
