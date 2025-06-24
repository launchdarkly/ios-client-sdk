import Foundation

public class EnvironmentMetadata {
    public let applicationInfo: ApplicationInfo?
    public let sdkMetadata: SdkMetadata
    public let credential: String
    
    public init(applicationInfo: ApplicationInfo?, sdkMetadata: SdkMetadata, credential: String) {
        self.applicationInfo = applicationInfo
        self.sdkMetadata = sdkMetadata
        self.credential = credential
    }
}
