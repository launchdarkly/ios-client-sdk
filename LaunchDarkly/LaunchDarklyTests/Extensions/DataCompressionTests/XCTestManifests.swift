
extension CompressionTest
{
    static var allTests = [
        ("testEmptyString", testEmptyString),
        ("testEmptyData", testEmptyData),
        ("testCrc32", testCrc32),
        ("testMiscSmall_gzip_gunzip", testMiscSmall_gzip_gunzip),
        ("testAsciiNumbers_gzip_gunzip", testAsciiNumbers_gzip_gunzip),
        ("testRandomDataChunks_gzip_gunzip", testRandomDataChunks_gzip_gunzip),
        ("testRandomDataBlob_16MB_gzip_gunzip", testRandomDataBlob_16MB_gzip_gunzip),
        ("testGzipCrcFail", testGzipCrcFail),
        ("testGzipISizeFail", testGzipISizeFail),
    ]
}
