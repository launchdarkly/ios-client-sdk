import XCTest
import Foundation

func symmetricAssertEqual<T: Equatable>(_ exp1: @autoclosure () throws -> T,
                                        _ exp2: @autoclosure () throws -> T,
                                        _ message: @autoclosure () -> String = "") {
    XCTAssertEqual(try exp1(), try exp2(), message())
    XCTAssertEqual(try exp2(), try exp1(), message())
}

func symmetricAssertNotEqual<T: Equatable>(_ exp1: @autoclosure () throws -> T,
                                           _ exp2: @autoclosure () throws -> T,
                                           _ message: @autoclosure () -> String = "") {
    XCTAssertNotEqual(try exp1(), try exp2(), message())
    XCTAssertNotEqual(try exp2(), try exp1(), message())
}
