import Foundation

/// Metadata about the LaunchDarkly SDK.
///
/// This class provides information about the SDK version and name for informational
/// purposes such as logging and debugging.
public class SdkMetadata {
    /// Name of the SDK for informational purposes such as logging.
    public let name: String

    /// Version of the SDK for informational purposes such as logging.
    public let version: String

    /// Initialize SDK metadata.
    ///
    /// - Parameters:
    ///   - name: Name of the SDK for informational purposes such as logging
    ///   - version: Version of the SDK for informational purposes such as logging
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}
