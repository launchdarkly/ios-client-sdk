import Foundation

/// Metadata about the environment that flag evaluations or other functionalities are being performed in.
///
/// This class provides context information to plugins about the environment they are running in,
/// including application information, SDK metadata, and authentication credentials.
public class EnvironmentMetadata {
    /// Application information for the application this SDK is used in.
    public let applicationInfo: ApplicationInfo?

    /// SDK metadata for the LaunchDarkly SDK.
    public let sdkMetadata: SdkMetadata

    /// Credential for authentication to LaunchDarkly endpoints for this environment.
    public let credential: String

    /// Initialize environment metadata.
    ///
    /// - Parameters:
    ///   - applicationInfo: Application information for the application this SDK is used in
    ///   - sdkMetadata: SDK metadata for the LaunchDarkly SDK
    ///   - credential: Credential for authentication to LaunchDarkly endpoints for this environment
    public init(applicationInfo: ApplicationInfo?, sdkMetadata: SdkMetadata, credential: String) {
        self.applicationInfo = applicationInfo
        self.sdkMetadata = sdkMetadata
        self.credential = credential
    }
}
