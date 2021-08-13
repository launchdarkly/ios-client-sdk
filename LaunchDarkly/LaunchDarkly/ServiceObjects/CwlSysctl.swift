//
//  CwlSysctl.swift
//  CwlUtils
//
//  Created by Matt Gallagher on 2016/02/03.
//  Copyright © 2016 Matt Gallagher ( http://cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//
//  LaunchDarkly Notes
//  This file is used on macOS to extract the device model from the system library
import Foundation

/// A "static"-only namespace around a series of functions that operate on buffers returned from the `Darwin.sysctl` function
struct Sysctl {
    /// Possible errors.
    enum Error: Swift.Error {
        case unknown
        case malformedUTF8
        case posixError(POSIXErrorCode)
    }

    /// Access the raw data for an array of sysctl identifiers.
    static func dataForKeys(_ keys: [Int32]) throws -> [Int8] {
        return try keys.withUnsafeBufferPointer { keysPointer throws -> [Int8] in
            // Preflight the request to get the required data size
            var requiredSize = 0
            let preFlightResult = Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), nil, &requiredSize, nil, 0)
            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map {
                    print($0.rawValue)
                    return Error.posixError($0)
                    } ?? Error.unknown
            }

            // Run the actual request with an appropriately sized array buffer
            let data = [Int8](repeating: 0, count: requiredSize)
            let result = data.withUnsafeBufferPointer { dataBuffer -> Int32 in
                return Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress), &requiredSize, nil, 0)
            }
            if result != 0 {
                throw POSIXErrorCode(rawValue: errno).map {
                    Error.posixError($0)
                } ?? Error.unknown
            }

            return data
        }
    }

    /// Invoke `sysctl` with an array of identifers, interpreting the returned buffer as a `String`. This function will throw `Error.malformedUTF8` if the buffer returned from `sysctl` cannot be interpreted as a UTF8 buffer.
    static func stringForKeys(_ keys: [Int32]) throws -> String {
        let optionalString = try dataForKeys(keys).withUnsafeBufferPointer { dataPointer -> String? in
            dataPointer.baseAddress.flatMap {
                String(validatingUTF8: $0)
            }
        }
        guard let str = optionalString
        else {
            throw Error.malformedUTF8
        }
        return str
    }

    /// e.g. "MacPro4,1"
    static var model: String {
        // swiftlint:disable:next force_try
        return try! Sysctl.stringForKeys([CTL_HW, HW_MODEL])
    }
}
