import Foundation

@objc(LDContext)
public final class ObjcLDContext: NSObject {
    var context: LDContext

    init(_ context: LDContext) {
        self.context = context
    }

    @objc public func fullyQualifiedKey() -> String { context.fullyQualifiedKey() }
    @objc public func isMulti() -> Bool { context.isMulti() }
    @objc public func contextKeys() -> [String: String] { context.contextKeys() }
    @objc public func getValue(reference: ObjcLDReference) -> ObjcLDValue? {
        guard let value = context.getValue(reference.reference)
        else { return nil }

        return ObjcLDValue(wrappedValue: value)
    }
}

@objc(LDContextBuilder)
public final class ObjcLDContextBuilder: NSObject {
    var builder: LDContextBuilder

    @objc public override init() {
        builder = LDContextBuilder()
    }

    @objc public init(key: String) {
        builder = LDContextBuilder(key: key)
    }

    // Initializer to wrap the Swift LDContextBuilder into ObjcLDContextBuilder for use in
    // Objective-C apps.
    init(_ builder: LDContextBuilder) {
        self.builder = builder
    }

    @objc public func kind(kind: String) { builder.kind(kind) }
    @objc public func key(key: String) { builder.key(key) }
    @objc public func name(name: String) { builder.name(name) }
    @objc public func secondary(secondary: String) { builder.secondary(secondary) }
    @objc public func anonymous(anonymous: Bool) { builder.anonymous(anonymous) }
    @objc public func addPrivateAttribute(reference: ObjcLDReference) { builder.addPrivateAttribute(reference.reference) }
    @objc public func removePrivateAttribute(reference: ObjcLDReference) { builder.removePrivateAttribute(reference.reference) }

    @discardableResult
    @objc public func trySetValue(name: String, value: ObjcLDValue) -> Bool {
        builder.trySetValue(name, value.wrappedValue)
    }

    @objc public func build() -> ContextBuilderResult {
        switch builder.build() {
        case .success(let context):
            return ContextBuilderResult.fromSuccess(context)
        case .failure(let error):
            return ContextBuilderResult.fromError(error)
        }
    }
}

@objc(LDMultiContextBuilder)
public final class ObjcLDMultiContextBuilder: NSObject {
    var builder: LDMultiContextBuilder

    @objc public override init() {
        builder = LDMultiContextBuilder()
    }

    @objc public func addContext(context: ObjcLDContext) {
        builder.addContext(context.context)
    }

    // Initializer to wrap the Swift LDMultiContextBuilder into ObjcLDMultiContextBuilder for use in
    // Objective-C apps.
    init(_ builder: LDMultiContextBuilder) {
        self.builder = builder
    }

    @objc public func build() -> ContextBuilderResult {
        switch builder.build() {
        case .success(let context):
            return ContextBuilderResult.fromSuccess(context)
        case .failure(let error):
            return ContextBuilderResult.fromError(error)
        }
    }
}

@objc public class ContextBuilderResult: NSObject {
    @objc public private(set) var success: ObjcLDContext?
    @objc public private(set) var failure: NSError?

    private override init() {
        super.init()
        success = nil
        failure = nil
    }

    public static func fromSuccess(_ success: LDContext) -> ContextBuilderResult {
        ContextBuilderResult(success, nil)
    }

    public static func fromError(_ error: ContextBuilderError) -> ContextBuilderResult {
        ContextBuilderResult(nil, error)
    }

    private convenience init(_ arg1: LDContext?, _ arg2: ContextBuilderError?) {
        self.init()
        success = arg1.map { ObjcLDContext($0) }
        failure = arg2.map { $0 as NSError }
    }
}
