import Foundation

/// LDContext is a collection of attributes that can be referenced in flag evaluations and analytics
/// events.
///
/// To create an LDContext of a single kind, such as a user, you may use `LDContextBuilder`.
///
/// To create an LDContext with multiple kinds, use `LDMultiContextBuilder`.
@objc(LDContext)
public final class ObjcLDContext: NSObject {
    var context: LDContext

    init(_ context: LDContext) {
        self.context = context
    }

    /// FullyQualifiedKey returns a string that describes the entire Context based on Kind and Key values.
    ///
    /// This value is used whenever LaunchDarkly needs a string identifier based on all of the Kind and
    /// Key values in the context; the SDK may use this for caching previously seen contexts, for instance.
    @objc public func fullyQualifiedKey() -> String { context.fullyQualifiedKey() }
    /// - Returns: true if the `LDContext` is a multi-context; false otherwise.
    @objc public func isMulti() -> Bool { context.isMulti() }
    //// - Returns: A hash mapping a context's kind to its key.
    @objc public func contextKeys() -> [String: String] { context.contextKeys() }
    /// Looks up the value of any attribute of the `LDContext`, or a value contained within an
    /// attribute, based on a `Reference`. This includes only attributes that are addressable in evaluations.
    ///
    /// This implements the same behavior that the SDK uses to resolve attribute references during a flag
    /// evaluation. In a context, the `Reference` can represent a simple attribute name-- either a
    /// built-in one like "name" or "key", or a custom attribute that was set by `LDContextBuilder.trySetValue(...)`--
    /// or, it can be a slash-delimited path using a JSON-Pointer-like syntax. See `Reference` for more details.
    ///
    /// For a multi-context, the only supported attribute name is "kind".
    ///
    /// If the value is found, the return value is the attribute value, using the type `LDValue` to
    /// represent a value of any JSON type.
    ///
    /// If there is no such attribute, or if the `Reference` is invalid, the return value is nil.
    @objc public func getValue(reference: ObjcLDReference) -> ObjcLDValue? {
        guard let value = context.getValue(reference.reference)
        else { return nil }

        return ObjcLDValue(wrappedValue: value)
    }
}

/// Contains methods for building a single kind `LDContext` with a specified key, defaulting to kind
/// "user".
///
/// You may use these methods to set additional attributes and/or change the kind before calling
/// `LDContextBuilder.build()`. If you do not change any values, the defaults for the `LDContext` are that its
/// kind is "user", its key is set to whatever value you passed to `LDContextBuilder.init(key:)`, its anonymous attribute
/// is false, and it has no values for any other attributes.
///
/// To define a multi-context, see `LDMultiContextBuilder`.
@objc(LDContextBuilder)
public final class ObjcLDContextBuilder: NSObject {
    var builder: LDContextBuilder

    /// Create a new LDContextBuilder.
    ///
    /// By default, this builder will create an anonymous LDContext with a generated key. This key will be cached
    /// locally and reused for the same context kind.
    ///
    /// If `LDContextBuilder.key` is called, a key will no longer be generated and the anonymous status will match the
    /// value provided by `LDContextBuilder.anonymous` or false by default.
    @objc public override init() {
        builder = LDContextBuilder()
    }

    /// Create a new LDContextBuilder with the provided `key`.
    @objc public init(key: String) {
        builder = LDContextBuilder(key: key)
    }

    // Initializer to wrap the Swift LDContextBuilder into ObjcLDContextBuilder for use in
    // Objective-C apps.
    init(_ builder: LDContextBuilder) {
        self.builder = builder
    }

    /// Sets the LDContext's kind attribute.
    ///
    /// Every LDContext has a kind. Setting it to an empty string is equivalent to the default kind
    /// of "user". This value is case-sensitive. Validation rules are as follows:
    ///
    /// - It may only contain letters, numbers, and the characters ".", "_", and "-".
    /// - It cannot equal the literal string "kind".
    /// - It cannot equal "multi".
    ///
    /// If the value is invalid, you will receive an error when `LDContextBuilder.build()` is called.
    @objc public func kind(kind: String) { builder.kind(kind) }
    /// Sets the LDContext's key attribute.
    ///
    /// Every LDContext has a key, which is always a string. There are no restrictions on its value other than it cannot
    /// be empty.
    ///
    /// The key attribute can be referenced by flag rules, flag target lists, and segments.
    @objc public func key(key: String) { builder.key(key) }
    /// Sets the LDContext's name attribute.
    ///
    /// This attribute is optional. It has the following special rules:
    ///
    /// - Unlike most other attributes, it is always a string if it is specified.
    /// - The LaunchDarkly dashboard treats this attribute as the preferred display name for users.
    @objc public func name(name: String) { builder.name(name) }
    /// Sets whether the LDContext is only intended for flag evaluations and should not be indexed by
    /// LaunchDarkly.
    ///
    /// The default value is false. False means that this LDContext represents an entity such as a
    /// user that you want to be able to see on the LaunchDarkly dashboard.
    ///
    /// Setting anonymous to true excludes this LDContext from the database that is used by the
    /// dashboard. It does not exclude it from analytics event data, so it is not the same as
    /// making attributes private; all non-private attributes will still be included in events and
    /// data export.
    ///
    /// This value is also addressable in evaluations as the attribute name "anonymous". It is
    /// always treated as a boolean true or false in evaluations.
    @objc public func anonymous(anonymous: Bool) { builder.anonymous(anonymous) }
    /// Provide a reference to designate any number of LDContext attributes as private: that is,
    /// their values will not be sent to LaunchDarkly.
    ///
    /// This action only affects analytics events that involve this particular `LDContext`. To mark some (or all)
    /// Context attributes as private for all contexts, use the overall event configuration for the SDK.
    ///
    /// In this example, firstName is marked as private, but lastName is not:
    ///
    /// ```swift
    /// var builder = LDContextBuilder(key: "my-key")
    /// builder.kind("org")
    /// builder.trySetValue("firstName", "Pierre")
    /// builder.trySetValue("lastName", "Menard")
    /// builder.addPrivate(Reference("firstName"))
    ///
    /// let context = try builder.build().get()
    /// ```
    ///
    /// The attributes "kind", "key", and "anonymous" cannot be made private.
    ///
    /// This is a metadata property, rather than an attribute that can be addressed in evaluations: that is,
    /// a rule clause that references the attribute name "private" will not use this value, but instead will
    /// use whatever value (if any) you have set for that name with `trySetValue(...)`.
    ///
    /// # Designating an entire attribute as private
    ///
    /// If the parameter is an attribute name such as "email" that does not start with a '/' character, the
    /// entire attribute is private.
    ///
    /// # Designating a property within a JSON object as private
    ///
    /// If the parameter starts with a '/' character, it is interpreted as a slash-delimited path to a
    /// property within a JSON object. The first path component is an attribute name, and each following
    /// component is a property name.
    ///
    /// For instance, suppose that the attribute "address" had the following JSON object value:
    /// {"street": {"line1": "abc", "line2": "def"}, "city": "ghi"}
    ///
    ///   - Calling either addPrivateAttribute(Reference("address")) or addPrivateAddress(Reference("/address")) would
    ///     cause the entire "address" attribute to be private.
    ///   - Calling addPrivateAttribute("/address/street") would cause the "street" property to be private, so that
    ///     only {"city": "ghi"} is included in analytics.
    ///   - Calling addPrivateAttribute("/address/street/line2") would cause only "line2" within "street" to be private,
    ///     so that {"street": {"line1": "abc"}, "city": "ghi"} is included in analytics.
    ///
    /// This syntax deliberately resembles JSON Pointer, but other JSON Pointer features such as array
    /// indexing are not supported.
    ///
    /// If an attribute's actual name starts with a '/' character, you must use the same escaping syntax as
    /// JSON Pointer: replace "~" with "~0", and "/" with "~1".
    @objc public func addPrivateAttribute(reference: ObjcLDReference) { builder.addPrivateAttribute(reference.reference) }
    /// Remove any reference provided through `addPrivateAttribute(_:)`. If the reference was
    /// added more than once, this method will remove all instances of it.
    @objc public func removePrivateAttribute(reference: ObjcLDReference) { builder.removePrivateAttribute(reference.reference) }

    /// Sets the value of any attribute for the Context except for private attributes.
    ///
    /// This method uses the `LDValue` type to represent a value of any JSON type: null,
    /// boolean, number, string, array, or object. For all attribute names that do not have special
    /// meaning to LaunchDarkly, you may use any of those types. Values of different JSON types are
    /// always treated as different values: for instance, null, false, and the empty string "" are
    /// not the same, and the number 1 is not the same as the string "1".
    ///
    /// The following attribute names have special restrictions on their value types, and any value
    /// of an unsupported type will be ignored (leaving the attribute unchanged):
    ///
    /// - "kind", "key": Must be a string. See `LDContextBuilder.kind(_:)` and `LDContextBuilder.key(_:)`.
    ///
    /// - "name": Must be a string or null. See `LDContextBuilder.name(_:)`.
    ///
    /// - "anonymous": Must be a boolean. See `LDContextBuilder.anonymous(_:)`.
    ///
    /// Values that are JSON arrays or objects have special behavior when referenced in
    /// flag/segment rules.
    ///
    /// A value of `LDValue.null` is equivalent to removing any current non-default value
    /// of the attribute. Null is not a valid attribute value in the LaunchDarkly model; any
    /// expressions in feature flags that reference an attribute with a null value will behave as
    /// if the attribute did not exist.
    ///
    /// This method returns true for success, or false if the parameters
    /// violated one of the restrictions described above (for instance,
    /// attempting to set "key" to a value that was not a string).
    @discardableResult
    @objc public func trySetValue(name: String, value: ObjcLDValue) -> Bool {
        builder.trySetValue(name, value.wrappedValue)
    }

    /// Creates a LDContext from the current LDContextBuilder properties.
    ///
    /// The LDContext is immutable and will not be affected by any subsequent actions on the
    /// LDContextBuilder.
    ///
    /// It is possible to specify invalid attributes for a LDContextBuilder, such as an empty key.
    /// In those situations, this method returns a Result.failure
    @objc public func build() -> ContextBuilderResult {
        switch builder.build() {
        case .success(let context):
            return ContextBuilderResult.fromSuccess(context)
        case .failure(let error):
            return ContextBuilderResult.fromError(error)
        }
    }
}

/// Contains method for building a multi-context.
///
/// Use this type if you need to construct a LDContext that has multiple kind values, each with its
/// own nested LDContext. To define a single-kind context, use `LDContextBuilder` instead.
///
/// Obtain an instance of LDMultiContextBuilder by calling `LDMultiContextBuilder.init()`; then, call
/// `LDMultiContextBuilder.addContext(_:)` to specify the nested LDContext for each kind.
/// LDMultiContextBuilder setters return a reference the same builder, so they can be chained
/// together.
@objc(LDMultiContextBuilder)
public final class ObjcLDMultiContextBuilder: NSObject {
    var builder: LDMultiContextBuilder

    @objc public override init() {
        builder = LDMultiContextBuilder()
    }

    /// Adds a nested context for a specific kind to a LDMultiContextBuilder.
    ///
    /// It is invalid to add more than one context with the same Kind. This error is detected when
    /// you call `LDMultiContextBuilder.build()`.
    @objc public func addContext(context: ObjcLDContext) {
        builder.addContext(context.context)
    }

    // Initializer to wrap the Swift LDMultiContextBuilder into ObjcLDMultiContextBuilder for use in
    // Objective-C apps.
    init(_ builder: LDMultiContextBuilder) {
        self.builder = builder
    }

    /// Creates a LDContext from the current properties.
    ///
    /// The LDContext is immutable and will not be affected by any subsequent actions on the
    /// LDMultiContextBuilder.
    ///
    /// It is possible for a LDMultiContextBuilder to represent an invalid state. In those
    /// situations, a Result.failure will be returned.
    ///
    /// If only one context kind was added to the builder, `build` returns a single-kind context rather
    /// than a multi-context.
    @objc public func build() -> ContextBuilderResult {
        switch builder.build() {
        case .success(let context):
            return ContextBuilderResult.fromSuccess(context)
        case .failure(let error):
            return ContextBuilderResult.fromError(error)
        }
    }
}

/// An NSObject which mimics Swift's Result type, specifically for the `LDContext` type.
@objc public class ContextBuilderResult: NSObject {
    @objc public private(set) var success: ObjcLDContext?
    @objc public private(set) var failure: NSError?

    private override init() {
        super.init()
        success = nil
        failure = nil
    }

    /// Create a "success" result with the provided `LDContext`.
    public static func fromSuccess(_ success: LDContext) -> ContextBuilderResult {
        ContextBuilderResult(success, nil)
    }

    /// Create an "error" result with the provided `LDContext`.
    public static func fromError(_ error: ContextBuilderError) -> ContextBuilderResult {
        ContextBuilderResult(nil, error)
    }

    private convenience init(_ arg1: LDContext?, _ arg2: ContextBuilderError?) {
        self.init()
        success = arg1.map { ObjcLDContext($0) }
        failure = arg2.map { $0 as NSError }
    }
}
