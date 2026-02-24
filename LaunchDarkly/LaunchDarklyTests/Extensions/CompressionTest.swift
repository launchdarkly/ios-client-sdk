
import XCTest

@testable import LaunchDarkly


extension Data
{
    func gzip_gunzip()     -> Data? { return c_gzip()?.c_gunzip() }

    func c_gzip()     -> Data? { let res: Data? = self.gzip();     XCTAssertNotNil(res, "\(#function) failed"); return res }
    func c_gunzip()   -> Data? { let res: Data? = self.gunzip();   XCTAssertNotNil(res, "\(#function) failed"); return res }
}


extension String
{
    func gzip_gunzip()     -> Data? { return data(using: .ascii)?.gzip_gunzip() }
}


class CompressionTest: XCTestCase
{
    static var blob16mb: Data!

    override class func setUp()
    {
        super.setUp()
        let b = 1024 * 1024 * 16 // 16 MB
        let ints = [UInt32](repeating: 0, count: b / 4).map { _ in arc4random() }
        self.blob16mb = Data(bytes: ints, count: b)
    }

    func testEmptyString()
    {
        XCTAssertEqual(Data(), "".gzip_gunzip())
    }

    func testEmptyData()
    {
        XCTAssertEqual(Data(), Data().gzip_gunzip())
    }

    func testCrc32()
    {
        var crc = Crc32()
        XCTAssertEqual(crc.checksum, 0x0)
        crc.advance(withChunk: "The quick brown ".data(using: .ascii)!)
        crc.advance(withChunk: "fox jumps over ".data(using: .ascii)!)
        crc.advance(withChunk: "the lazy dog.".data(using: .ascii)!)
        XCTAssertEqual(crc.checksum, 0x519025e9)
    }
    
    func testMiscSmall_gzip_gunzip()
    {
        for i in 1...500 {
            let s = String(repeating: "a", count: i)
            XCTAssertEqual(s.data(using: .ascii), s.gzip_gunzip(), "Fails with: \(s)")
        }
    }

    func testAsciiNumbers_gzip_gunzip()
    {
        for i in 1...500 {
            let r = sqrt(Double(i)) / .pi 
            let s = String(repeating: "\(r)", count: i)
            XCTAssertEqual(s.data(using: .ascii), s.gzip_gunzip(), "Fails with: \(s)")
        }
    }

    func testRandomDataChunks_gzip_gunzip()
    {
        for i in 1...500 {
            let ints = [UInt32](repeating: 0, count: 1 + (i / 4)).map { _ in arc4random() }
            let data = Data(bytes: ints, count: i)
            XCTAssertEqual(data, data.gzip_gunzip(), "Fails with random data (\(data.count) bytes) :(")
        }
    }

    func testRandomDataBlob_16MB_gzip_gunzip()
    {
        XCTAssertEqual(CompressionTest.blob16mb, CompressionTest.blob16mb.gzip_gunzip())
    }

    func testGzipCrcFail()
    {
        let b = 1024 * 16
        let ints = [UInt32](repeating: 0xcafeabee, count: b / 4)
        var zipped_blob = Data(bytes: ints, count: b).gzip()!

        let wrong_crc = Data(bytes: [0xcafeabee], count: 1)
        let range = (zipped_blob.count - 8)..<(zipped_blob.count - 4)
        zipped_blob.replaceSubrange(range, with: wrong_crc)

        XCTAssertNil(zipped_blob.gunzip())
    }

    func testGzipISizeFail()
    {
        let b = 1024 * 16
        let ints = [UInt32](repeating: 0xcafeabee, count: b / 4)
        var zipped_blob = Data(bytes: ints, count: b).gzip()!

        let wrong_isize = Data(bytes: [0xcafeabee], count: 1)
        let range = (zipped_blob.count - 4)..<(zipped_blob.count)
        zipped_blob.replaceSubrange(range, with: wrong_isize)

        XCTAssertNil(zipped_blob.gunzip())
    }
}
