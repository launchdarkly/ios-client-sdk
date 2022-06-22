import Foundation

@objc(Reference)
public final class ObjcLDReference: NSObject {
    var reference: Reference

    @objc public init(value: String) {
        reference = Reference(value)
    }

    // Initializer to wrap the Swift Reference into ObjcLDReference for use in
    // Objective-C apps.
    init(_ reference: Reference) {
        self.reference = reference
    }

    @objc public func isValid() -> Bool { reference.isValid() }

    @objc public func getError() -> NSError? {
        guard let error = reference.getError()
        else { return nil }

        return error as NSError
    }
}

@objc(ReferenceError)
public final class ObjcLDReferenceError: NSObject {
    var error: ReferenceError

    // Initializer to wrap the Swift ReferenceError into ObjcLDReferenceError for use in
    // Objective-C apps.
    init(_ error: ReferenceError) {
        self.error = error
    }

    override public var description: String { self.error.description }
}
